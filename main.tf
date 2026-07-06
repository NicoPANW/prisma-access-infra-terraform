# ==============================================================================
# TERRAFORM SETTINGS & PROVIDER CONFIGURATION
# ==============================================================================
terraform {
  # Ensure the local environment runs a supported version of Terraform
  required_version = ">= 1.3.0"
  required_providers {
    scm = {
      # Strata Cloud Manager (SCM) provider for managing Prisma Access resources
      source  = "PaloAltoNetworks/scm"
      version = "~> 1.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}

# Execute SCM Token Cache Service atomically during the planning phase
data "external" "token_refresh" {
  program = ["python3", "${path.module}/token_cache_service.py"]
}

locals {
  # Dynamically bind to the refreshed credentials returned by the external script execution.
  # This guarantees we first check if the token is valid, refresh it if expired, and use it directly.
  scm_token   = data.external.token_refresh.result.jwt
  scm_host    = try(data.external.token_refresh.result.host, "api.strata.paloaltonetworks.com")
}

# Configure SCM provider utilizing the dynamically refreshed and verified JWT token file.
# By referencing the external token_refresh data source, we force Terraform to refresh
# the token before the SCM provider initializes.
provider "scm" {
  host      = local.scm_host
  auth_file = data.external.token_refresh.result.auth_file
}

# ==============================================================================
# CRYPTO PROFILES
# ==============================================================================

# custom IKE cryptographic profile defining Phase 1 parameters
# of the IPSec VPN negotiation.
# Define custom IKE Cryptographic profile using specified high-security settings.
# These settings govern phase 1 of the IPSec VPN negotiation.
resource "scm_ike_crypto_profile" "ike" {
  name       = "TF_${var.ike_crypto_profile.name}"
  folder     = var.folder
  dh_group   = var.ike_crypto_profile.dh_group
  encryption = var.ike_crypto_profile.encryption
  hash       = var.ike_crypto_profile.hash
  lifetime = {
    seconds = 28800
  }
}

# custom IPSec cryptographic profile defining Phase 2 parameters
# of the IPSec VPN negotiation.
resource "scm_ipsec_crypto_profile" "ipsec" {
  name     = "TF_${var.ipsec_crypto_profile.name}"
  folder   = var.folder
  dh_group = var.ipsec_crypto_profile.dh_group
  esp = {
    encryption = var.ipsec_crypto_profile.encryption
    authentication = var.ipsec_crypto_profile.authentication
  }
  lifetime = {
    seconds = 3600
  }
}

# ==============================================================================
# SERVICE CONNECTION INFRASTRUCTURE & RESOURCE
# ==============================================================================

# 1. IKE Gateway for Service Connection
resource "scm_ike_gateway" "sc_primary_gw" {
  for_each = var.service_connections
  name     = "TF_${each.value.primary_ike_gateway_name}"
  folder = "Service Connections"

  peer_address = {
    ip    = each.value.primary_peer_address
    #if no peer IP, it means dynamic
    dynamic = each.value.primary_peer_address == null ? {} : null
  }

  local_address = {
    interface = each.value.local_address_interface
  }

  local_id = each.value.primary_local_id != null ? {
    id   = each.value.primary_local_id.id
    type = each.value.primary_local_id.type
  } : null

  peer_id = {
    id   = each.value.primary_peer_id.id
    type = each.value.primary_peer_id.type
  }

  authentication = {
    pre_shared_key = {
      key = each.value.primary_psk
    }
  }

  protocol = {
    version = "ikev2"
    ikev2 = {
      # Explicit graph link: checks if using custom managed profile, otherwise falls back to variable string
      ike_crypto_profile = each.value.primary_ike_crypto_profile == "TF_prod-ike-crypto-profile" ? scm_ike_crypto_profile.ike.name : each.value.primary_ike_crypto_profile
      dpd = {
        enable = true
      }
    }
  }
  
  protocol_common = {
    passive_mode = each.value.passive_mode
    nat_traversal = {
      enable = true
    }
    fragmentation = {
      enable = false
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 2. IKE Secondary Gateway for HA Service Connection (instantiated conditionally)
resource "scm_ike_gateway" "sc_secondary_gw" {
  for_each = { for k, v in var.service_connections : k => v if v.enable_secondary }
  name     = "TF_${each.value.secondary_ike_gateway_name}"
  folder   = "Service Connections"

  peer_address = {
    ip    = each.value.secondary_peer_address
    #if no peer IP, it means dynamic
    dynamic = each.value.secondary_peer_address == null ? {} : null
  }

  local_address = {
    interface = each.value.local_address_interface
  }

  local_id = each.value.secondary_local_id != null ? {
    id   = each.value.secondary_local_id.id
    type = each.value.secondary_local_id.type
  } : null

  peer_id = {
    id   = each.value.secondary_peer_id.id
    type = each.value.secondary_peer_id.type
  }

  authentication = {
    pre_shared_key = {
      key = each.value.secondary_psk
    }
  }

  protocol = {
    version = "ikev2"
    ikev2 = {
      ike_crypto_profile = each.value.secondary_ike_crypto_profile == "TF_prod-ike-crypto-profile" ? scm_ike_crypto_profile.ike.name : each.value.secondary_ike_crypto_profile
      dpd = {
        enable = true
      }
    }
  }
  
  protocol_common = {
    passive_mode = each.value.passive_mode
    nat_traversal = {
      enable = true
    }
    fragmentation = {
      enable = false
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 2. IPSec Tunnel for Service Connection
resource "scm_ipsec_tunnel" "sc_primary_tunnel" {
  for_each = var.service_connections
  name     = "TF_${each.value.primary_ipsec_tunnel_name}"
  folder = "Service Connections"
  tunnel_interface         = "tunnel"
  anti_replay              = true
  copy_tos                 = false
  enable_gre_encapsulation = false
  
  auto_key = {
    ike_gateway = [{
      name = scm_ike_gateway.sc_primary_gw[each.key].name
    }]
    ipsec_crypto_profile = each.value.primary_ipsec_crypto_profile == "TF_prod-ipsec-crypto-profile" ? scm_ipsec_crypto_profile.ipsec.name : each.value.primary_ipsec_crypto_profile
  }

  tunnel_monitor = {
    enable         = true
    destination_ip = each.value.primary_tunnel_monitor_ip
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    scm_ike_gateway.sc_primary_gw
  ]
}

# 2. IPSec Secondary Tunnel for HA Service Connection (instantiated conditionally)
resource "scm_ipsec_tunnel" "sc_secondary_tunnel" {
  for_each = { for k, v in var.service_connections : k => v if v.enable_secondary }
  name     = "TF_${each.value.secondary_ipsec_tunnel_name}"
  folder   = "Service Connections"
  tunnel_interface         = "tunnel"
  anti_replay              = true
  copy_tos                 = false
  enable_gre_encapsulation = false
  
  auto_key = {
    ike_gateway = [{
      name = scm_ike_gateway.sc_secondary_gw[each.key].name
    }]
    ipsec_crypto_profile = each.value.secondary_ipsec_crypto_profile == "TF_prod-ipsec-crypto-profile" ? scm_ipsec_crypto_profile.ipsec.name : each.value.secondary_ipsec_crypto_profile
  }

  tunnel_monitor = {
    enable         = true
    destination_ip = each.value.secondary_tunnel_monitor_ip
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    scm_ike_gateway.sc_secondary_gw
  ]
}

# 3. Service Connection Resource itself
resource "scm_service_connection" "sc" {
  for_each     = var.service_connections
  name         = "TF_${each.value.name}"
  ipsec_tunnel = scm_ipsec_tunnel.sc_primary_tunnel[each.key].name
  secondary_ipsec_tunnel = each.value.enable_secondary ? scm_ipsec_tunnel.sc_secondary_tunnel[each.key].name : null
  region       = try(local.display_to_cloud_region[each.value.region], each.value.region)
  region_tag   = each.value.region_tag
  subnets      = each.value.subnets

  # Directly maps the root-level bgp_peer object as a single nested attribute
  bgp_peer = try(each.value.bgp_peer, null) != null ? {
    enable           = try(each.value.bgp_peer.enable, true)
    same_as_primary  = each.value.bgp_peer.same_as_primary
    peer_ip_address  = each.value.bgp_peer.peer_ip_address
    local_ip_address = each.value.bgp_peer.local_ip_address
    secret           = try(each.value.bgp_peer.secret, null)
  } : null

protocol = {
    bgp = {
      enable           = each.value.protocol.bgp.enable
      peer_as          = each.value.protocol.bgp.peer_as
      peer_ip_address  = each.value.protocol.bgp.peer_ip_address
      local_ip_address = each.value.protocol.bgp.local_ip_address
    }
  }
}

# ==============================================================================
# REMOTE NETWORKS INFRASTRUCTURE & RESOURCES
# ==============================================================================

# 1. IKE Gateways for Remote Networks
resource "scm_ike_gateway" "rn_primary_gw" {
  # Create one IKE Gateway per remote network item defined in the tfvars map
  for_each = var.remote_networks
  name     = "TF_${each.value.primary_ike_gateway_name}"
  folder   = "Remote Networks"

  peer_address = {
    ip      = each.value.primary_peer_address
    dynamic = each.value.primary_peer_address == null ? {} : null
  }

  local_address = {
    interface = each.value.local_address_interface
  }

  local_id = each.value.primary_local_id != null ? {
    id   = each.value.primary_local_id.id
    type = each.value.primary_local_id.type
  } : null

  peer_id = {
    id   = each.value.primary_peer_id.id
    type = each.value.primary_peer_id.type
  }

  authentication = {
    pre_shared_key = {
      key = each.value.primary_psk
    }
  }

  protocol = {
    # Bind the protocol definition to IKEv2 and link our custom cryptographic profile
    version = "ikev2"
    ikev2 = {
      ike_crypto_profile = each.value.primary_ike_crypto_profile == "TF_prod-ike-crypto-profile" ? scm_ike_crypto_profile.ike.name : each.value.primary_ike_crypto_profile
      dpd = {
        enable = true
      }
    }
  }

  protocol_common = {
    passive_mode = each.value.passive_mode
    nat_traversal = {
      enable = true
    }
    fragmentation = {
      enable = false
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 1. IKE Secondary Gateway for Remote Networks (instantiated conditionally)
resource "scm_ike_gateway" "rn_secondary_gw" {
  for_each = { for k, v in var.remote_networks : k => v if v.enable_secondary }
  name     = "TF_${each.value.secondary_ike_gateway_name}"
  folder   = "Remote Networks"

  peer_address = {
    ip      = lookup(each.value, "secondary_peer_address", null)
    dynamic = lookup(each.value, "secondary_peer_address", null) == null ? {} : null
  }

  local_address = {
    interface = each.value.local_address_interface
  }

  local_id = each.value.secondary_local_id != null ? {
    id   = each.value.secondary_local_id.id
    type = each.value.secondary_local_id.type
  } : null

  peer_id = {
    id   = each.value.secondary_peer_id.id
    type = each.value.secondary_peer_id.type
  }

  authentication = {
    pre_shared_key = {
      key = each.value.secondary_psk
    }
  }

  protocol = {
    version = "ikev2"
    ikev2 = {
      ike_crypto_profile = each.value.secondary_ike_crypto_profile == "TF_prod-ike-crypto-profile" ? scm_ike_crypto_profile.ike.name : each.value.secondary_ike_crypto_profile
      dpd = {
        enable = true
      }
    }
  }

  protocol_common = {
    passive_mode = each.value.passive_mode
    nat_traversal = {
      enable = true
    }
    fragmentation = {
      enable = false
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 2. IPSec Tunnels for Remote Networks
resource "scm_ipsec_tunnel" "rn_primary_tunnel" {
  # Build tunnels for each Remote Network linking dynamically to their matching IKE Gateway
  for_each = var.remote_networks
  name     = "TF_${each.value.primary_ipsec_tunnel_name}"
  folder   = "Remote Networks"
  tunnel_interface         = "tunnel"
  anti_replay              = true
  copy_tos                 = false
  enable_gre_encapsulation = false

  auto_key = {
    ike_gateway = [{
      name = scm_ike_gateway.rn_primary_gw[each.key].name
    }]
    ipsec_crypto_profile = each.value.primary_ipsec_crypto_profile == "TF_prod-ipsec-crypto-profile" ? scm_ipsec_crypto_profile.ipsec.name : each.value.primary_ipsec_crypto_profile
  }

  tunnel_monitor = {
    enable         = true
    destination_ip = each.value.primary_tunnel_monitor_ip
  }

  depends_on = [
    # Ensure the matching IKE gateways are active before establishing phase 2 tunnels
    scm_ike_gateway.rn_primary_gw
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# 2. IPSec Secondary Tunnel for HA Remote Networks (instantiated conditionally)
resource "scm_ipsec_tunnel" "rn_secondary_tunnel" {
  for_each = { for k, v in var.remote_networks : k => v if v.enable_secondary }
  name     = "TF_${each.value.secondary_ipsec_tunnel_name}"
  folder   = "Remote Networks"
  tunnel_interface         = "tunnel"
  anti_replay              = true
  copy_tos                 = false
  enable_gre_encapsulation = false

  auto_key = {
    ike_gateway = [{
      name = scm_ike_gateway.rn_secondary_gw[each.key].name
    }]
    ipsec_crypto_profile = each.value.secondary_ipsec_crypto_profile == "TF_prod-ipsec-crypto-profile" ? scm_ipsec_crypto_profile.ipsec.name : each.value.secondary_ipsec_crypto_profile
  }

  tunnel_monitor = {
    enable         = true
    destination_ip = each.value.secondary_tunnel_monitor_ip
  }

  depends_on = [
    scm_ike_gateway.rn_secondary_gw
  ]

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  # Check if the region mappings file exists before attempting to read it to prevent plan-time compilation crashes
  mappings_file_exists = fileexists("${path.module}/RN-region-mappings.json")

  # Safe decode fallback to an empty array if the mappings file has not been generated yet
  raw_locations = local.mappings_file_exists ? jsondecode(file("${path.module}/RN-region-mappings.json")) : []

  # Map 1: Translates the raw display region (e.g. "France North") to SCM's "aggregate_region" (e.g. "france-north") for bandwidth
  display_to_bandwidth_region = {
    for loc in local.raw_locations : try(loc.display, "unknown") => try(loc.aggregate_region, "unknown")
    if try(loc.display, null) != null && try(loc.aggregate_region, null) != null
  }

  # Map 2: Translates the raw display region (e.g. "France North") to standard cloud provider "value" (e.g. "eu-west-3") for RN
  display_to_cloud_region = {
    for loc in local.raw_locations : try(loc.display, "unknown") => try(loc.value, "unknown")
    if try(loc.display, null) != null && try(loc.value, null) != null
  }

  # Group and consolidate Remote Network bandwidth allocations by their translated SCM Bandwidth Region ("aggregate_region")
  region_bandwidth_groups = {
    for key, val in var.remote_networks : try(local.display_to_bandwidth_region[val.region], val.region) => val.bandwidth...
  }

  region_bandwidth_totals = {
    # Sum all bandwidth entries per SCM Bandwidth Region into single consolidated regional requests
    for b_region, bandwidths in local.region_bandwidth_groups : b_region => sum(bandwidths)
  }
}

# 3. Bandwidth Allocation for Remote Network SPN Regions
resource "scm_bandwidth_allocation" "allocation" {
  # Deploy regional bandwidth allocations dynamically grouped by SCM region (e.g. us-west-2)
  for_each            = local.region_bandwidth_totals
  name                = each.key
  allocated_bandwidth = each.value
}

# 4. Remote Network Resources
resource "scm_remote_network" "rn" {
  for_each     = var.remote_networks
  name         = "TF_${each.value.name}"
  folder       = "Remote Networks"
  ipsec_tunnel = scm_ipsec_tunnel.rn_primary_tunnel[each.key].name
  secondary_ipsec_tunnel = each.value.enable_secondary ? scm_ipsec_tunnel.rn_secondary_tunnel[each.key].name : null
  # Translate the SCM Bandwidth Region to standard cloud provider compute regions for network attachment
  region       = try(local.display_to_cloud_region[each.value.region], each.value.region)
  # Implicit dependency: Retrieve the dynamically assigned SPN (Service PoP Node) name 
  # generated by SCM after the bandwidth allocation succeeds.
  spn_name     = scm_bandwidth_allocation.allocation[try(local.display_to_bandwidth_region[each.value.region], each.value.region)].spn_name_list[0]
  subnets      = each.value.subnets
  license_type = each.value.license_type

  # Apply BGP configuration dynamically. If disabled (like Cust2-RN2), BGP routing settings are omitted (null)
  protocol = each.value.bgp.enable ? {
    bgp = {
      enable                  = each.value.bgp.enable
      originate_default_route = each.value.bgp.originate_default_route
      peer_ip_address         = each.value.bgp.peer_ip_address
      peer_as                 = each.value.bgp.peer_as
      local_ip_address        = each.value.bgp.local_ip_address
      do_not_export_routes    = each.value.bgp.do_not_export_routes
    }
    bgp_peer = try(each.value.bgp_peer, null) != null ? {
      enable           = try(each.value.bgp_peer.enable, true)
      same_as_primary  = each.value.bgp_peer.same_as_primary
      peer_as          = try(each.value.bgp_peer.peer_as, each.value.bgp.peer_as)
      peer_ip_address  = each.value.bgp_peer.peer_ip_address
      local_ip_address = each.value.bgp_peer.local_ip_address
    } : null
  } : null

  lifecycle {
    create_before_destroy = true

    # Enforce a strict prerequisite check with an explicit, helpful error message
    precondition {
      condition     = local.mappings_file_exists
      error_message = "Prerequisite Missing: The file 'RN-region-mappings.json' was not found. Please run 'python3 RN_fetch_cloud_mapping_regions.py' beforehand to download the current region mappings database from Strata Cloud Manager."
    }
  }
}

# ==============================================================================
# SECURITY RULES
# ==============================================================================

# Pre-security rules allowing trusted network traffic to reach external destinations
resource "scm_security_rule" "secure_internet_access" {
  name            = "TF_Secure Internet Access - cust2"
  folder          = "Shared"
  position        = "pre"
  action          = "allow"
  from            = ["trust"]
  to              = ["any"]
  source          = ["any"]
  destination     = ["any"]
  source_user     = ["any"]
  category        = ["any"]
  application     = ["any"]
  service         = ["any"]
  source_hip      = ["any"]
  destination_hip = ["any"]
  log_setting     = "Cortex Data Lake"
  log_end         = true
  log_start       = false
  disabled        = false
  description     = "Secure Internet Access - cust2.  changing description to test config logs. Demo"
  profile_setting = {
    # Profile group reference mapped exactly to SCM's lowercase case-sensitive default.
    group = ["best-practice"]
  }
}