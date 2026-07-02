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
resource "scm_ike_gateway" "sc_gw" {
  # Prepend "TF_" prefix to maintain naming conventions across SCM tenant
  name   = "TF_${var.service_connection.ike_gateway_name}"
  folder = "Service Connections"

  peer_address = {
    # "dynamic = {}" instructs SCM to accept incoming connection requests from any IP.
    # This maps directly to the SCM API requirement of an empty object block.
    dynamic = {}
  }

  local_address = {
    # Bind the connection to the specified internal interface type (e.g., VLAN)
    interface = var.service_connection.local_address.interface
  }

  peer_id = {
    # Explicit Peer ID matching configuration on the remote peer gateway
    id   = var.service_connection.peer_id.id
    type = var.service_connection.peer_id.type
  }

  authentication = {
    pre_shared_key = {
      key = var.service_connection.psk
    }
  }

  protocol = {
    version = "ikev2"
    ikev2 = {
      ike_crypto_profile = scm_ike_crypto_profile.ike.name
      dpd = {
        enable = true
      }
    }
  }
  
  protocol_common = {
    # Passive mode means SCM waits for the remote peer gateway to initiate negotiations
    passive_mode = var.service_connection.passive_mode
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
resource "scm_ipsec_tunnel" "sc_tunnel" {
  name   = "TF_${var.service_connection.ipsec_tunnel_name}"
  folder = "Service Connections"
  tunnel_interface         = "tunnel"
  anti_replay              = true
  copy_tos                 = false
  enable_gre_encapsulation = false
  
  auto_key = {
    # Link the IPSec tunnel to our custom IKE gateway and IPSec crypto profile
    ike_gateway = [{
      name = scm_ike_gateway.sc_gw.name
    }]
    ipsec_crypto_profile = scm_ipsec_crypto_profile.ipsec.name
  }

  tunnel_monitor = {
    # Enable continuous tunnel keepalives pointing to the remote BGP peer IP
    enable         = var.service_connection.tunnel_monitor.enable
    destination_ip = var.service_connection.tunnel_monitor.destination_ip
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    # Prevent tunnel instantiation before the parent gateway configuration finishes
    scm_ike_gateway.sc_gw
  ]
}

# 3. Service Connection Resource itself
resource "scm_service_connection" "sc" {
  name         = "TF_${var.service_connection.name}"
  ipsec_tunnel = scm_ipsec_tunnel.sc_tunnel.name
  region       = try(local.display_to_cloud_region[var.service_connection.region], var.service_connection.region)
  region_tag   = var.service_connection.region_tag
  subnets      = var.service_connection.subnets

  protocol = {
    # BGP configuration allowing routing synchronization over the Service Connection
    bgp = {
      enable          = var.service_connection.bgp.enable
      peer_as         = var.service_connection.bgp.peer_as
      peer_ip_address = var.service_connection.bgp.peer_ip_address
    }
  }
}

# ==============================================================================
# REMOTE NETWORKS INFRASTRUCTURE & RESOURCES (x2)
# ==============================================================================

# 1. IKE Gateways for Remote Networks
resource "scm_ike_gateway" "rn_gw" {
  # Create one IKE Gateway per remote network item defined in the tfvars map
  for_each = var.remote_networks
  name     = "TF_${each.value.ike_gateway_name}"
  folder   = "Remote Networks"

  peer_address = {
    dynamic = {}
  }

  local_address = {
    interface = each.value.local_address.interface
  }

  peer_id = {
    id   = each.value.peer_id.id
    type = each.value.peer_id.type
  }

  authentication = {
    pre_shared_key = {
      key = each.value.psk
    }
  }

  protocol = {
    # Bind the protocol definition to IKEv2 and link our custom cryptographic profile
    version = "ikev2"
    ikev2 = {
      ike_crypto_profile = scm_ike_crypto_profile.ike.name
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
resource "scm_ipsec_tunnel" "rn_tunnel" {
  # Build tunnels for each Remote Network linking dynamically to their matching IKE Gateway
  for_each = var.remote_networks
  name     = "TF_${each.value.ipsec_tunnel_name}"
  folder   = "Remote Networks"
  tunnel_interface         = "tunnel"
  anti_replay              = true
  copy_tos                 = false
  enable_gre_encapsulation = false

  auto_key = {
    ike_gateway = [{
      name = scm_ike_gateway.rn_gw[each.key].name
    }]
    ipsec_crypto_profile = scm_ipsec_crypto_profile.ipsec.name
  }

  tunnel_monitor = {
    enable         = each.value.tunnel_monitor.enable
    destination_ip = each.value.tunnel_monitor.destination_ip
  }

  depends_on = [
    # Ensure the matching IKE gateways are active before establishing phase 2 tunnels
    scm_ike_gateway.rn_gw
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
  ipsec_tunnel = scm_ipsec_tunnel.rn_tunnel[each.key].name
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