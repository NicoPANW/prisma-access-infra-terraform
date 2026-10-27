# ==============================================================================
# TERRAFORM SETTINGS & PROVIDER CONFIGURATION
# ==============================================================================
terraform {
  # Ensure the local environment runs a supported version of Terraform
  required_version = ">= 1.14.0"
  required_providers {
    scm = {
      # Strata Cloud Manager (SCM) provider for managing Prisma Access resources
      source  = "PaloAltoNetworks/scm"
      version = "~> 1.0, >= 1.0.13"
    }
    ztna = {
      source  = "PaloAltoNetworks/scm"
      version = "~> 1.0, >= 1.0.13"
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

# Configure ZTNA provider endpoint with region header
provider "ztna" {
  auth_file     = data.external.token_refresh.result.auth_file
  ztna_host     = var.ztna_host
  x_panw_region = var.ztna_x_panw_region
}

# ==============================================================================
# CRYPTO PROFILES
# ==============================================================================

# custom IKE cryptographic profile defining Phase 1 parameters
# of the IPSec VPN negotiation.
# Define custom IKE Cryptographic profile using specified high-security settings.
# These settings govern phase 1 of the IPSec VPN negotiation.
resource "scm_ike_crypto_profile" "ike" {
  name       = startswith(var.ike_crypto_profile.name, "TF_") ? var.ike_crypto_profile.name : "TF_${var.ike_crypto_profile.name}"
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
  name     = startswith(var.ipsec_crypto_profile.name, "TF_") ? var.ipsec_crypto_profile.name : "TF_${var.ipsec_crypto_profile.name}"
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
  name     = startswith(each.value.primary_ike_gateway_name, "TF_") ? each.value.primary_ike_gateway_name : "TF_${each.value.primary_ike_gateway_name}"
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
  name     = startswith(each.value.secondary_ike_gateway_name, "TF_") ? each.value.secondary_ike_gateway_name : "TF_${each.value.secondary_ike_gateway_name}"
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
  name     = startswith(each.value.primary_ipsec_tunnel_name, "TF_") ? each.value.primary_ipsec_tunnel_name : "TF_${each.value.primary_ipsec_tunnel_name}"
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
  name     = startswith(each.value.secondary_ipsec_tunnel_name, "TF_") ? each.value.secondary_ipsec_tunnel_name : "TF_${each.value.secondary_ipsec_tunnel_name}"
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
  name         = startswith(each.value.name, "TF_") ? each.value.name : "TF_${each.value.name}"
  ipsec_tunnel = scm_ipsec_tunnel.sc_primary_tunnel[each.key].name
  secondary_ipsec_tunnel = each.value.enable_secondary ? scm_ipsec_tunnel.sc_secondary_tunnel[each.key].name : null
  region       = try(local.display_to_cloud_region[each.value.region], each.value.region)
  region_tag   = each.value.region_tag
  subnets      = each.value.subnets

  # Directly maps the root-level bgp_peer object as a single nested attribute
  #bgp_peer = try(each.value.bgp_peer, null) != null ? {
  #  enable           = try(each.value.bgp_peer.enable, true)
  #  same_as_primary  = each.value.bgp_peer.same_as_primary
  #  peer_ip_address  = each.value.bgp_peer.peer_ip_address
  #  local_ip_address = each.value.bgp_peer.local_ip_address
  #  secret           = try(each.value.bgp_peer.secret, null)
  #} : null

protocol = {
    bgp_peer = try(each.value.bgp_peer, null) != null ? {
      enable           = try(each.value.bgp_peer.enable, true)
      same_as_primary  = each.value.bgp_peer.same_as_primary
      peer_ip_address  = each.value.bgp_peer.peer_ip_address
      local_ip_address = each.value.bgp_peer.local_ip_address
      secret           = try(each.value.bgp_peer.secret, null)
    } : null
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
  name     = startswith(each.value.primary_ike_gateway_name, "TF_") ? each.value.primary_ike_gateway_name : "TF_${each.value.primary_ike_gateway_name}"
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
  name     = startswith(each.value.secondary_ike_gateway_name, "TF_") ? each.value.secondary_ike_gateway_name : "TF_${each.value.secondary_ike_gateway_name}"
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
  name     = startswith(each.value.primary_ipsec_tunnel_name, "TF_") ? each.value.primary_ipsec_tunnel_name : "TF_${each.value.primary_ipsec_tunnel_name}"
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
  name     = startswith(each.value.secondary_ipsec_tunnel_name, "TF_") ? each.value.secondary_ipsec_tunnel_name : "TF_${each.value.secondary_ipsec_tunnel_name}"
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

# Query Prisma Access locations natively from the SCM API
data "scm_location_list" "all" {}

locals {
  raw_locations = data.scm_location_list.all.data

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
    for key, val in var.remote_networks : 
    try(local.display_to_bandwidth_region[val.region], val.region) => val.bandwidth...
    if val.bandwidth != null
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
  name         = startswith(each.value.name, "TF_") ? each.value.name : "TF_${each.value.name}"
  folder       = "Remote Networks"
  ipsec_tunnel = scm_ipsec_tunnel.rn_primary_tunnel[each.key].name
  secondary_ipsec_tunnel = each.value.enable_secondary ? scm_ipsec_tunnel.rn_secondary_tunnel[each.key].name : null
  # Translate the SCM Bandwidth Region to standard cloud provider compute regions for network attachment
  region       = try(local.display_to_cloud_region[each.value.region], each.value.region)
  # Implicit dependency: Retrieve SPN if specified or if an aggregate bandwidth allocation exists; null for Site RNs.
  spn_name     = try(
    try(each.value.spn_name, null),
    scm_bandwidth_allocation.allocation[try(local.display_to_bandwidth_region[each.value.region], each.value.region)].spn_name_list[0],
    null
  )
  subnets             = each.value.subnets
  license_type        = try(each.value.site.license_type, each.value.license_type)
  ecmp_load_balancing = try(each.value.ecmp_load_balancing, null)

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
  }
}

# 5. Prisma Access Site Resource (Optional wrapper for branch sites)
resource "scm_site" "site" {
  for_each = {
    for k, v in var.remote_networks : k => v if v.site != null
  }

  name         = startswith(each.value.site.name, "TF_") ? each.value.site.name : "TF_${each.value.site.name}"
  type         = each.value.site.type
  license_type = each.value.site.license_type

  city      = each.value.site.city
  state     = each.value.site.state
  country   = each.value.site.country
  zip_code  = each.value.site.zip_code
  latitude  = each.value.site.latitude
  longitude = each.value.site.longitude

  members = concat(
    [
      {
        name           = scm_remote_network.rn[each.key].name
        remote_network = scm_remote_network.rn[each.key].name
        mode           = coalesce(each.value.site.mode, "active")
      }
    ],
    try(each.value.site.backup_remote_network, null) != null ? [
      {
        name           = scm_remote_network.rn[each.value.site.backup_remote_network].name
        remote_network = scm_remote_network.rn[each.value.site.backup_remote_network].name
        mode           = "backup"
      }
    ] : []
  )

  qos = each.value.site.qos != null ? {
    profile = each.value.site.qos.profile
    cir     = each.value.site.qos.cir
  } : null
}

# ==============================================================================
# SECURITY RULES
# ==============================================================================

# Dynamic security rules defined in terraform.tfvars
resource "scm_security_rule" "rule" {
  for_each        = var.security_rules
  name            = startswith(coalesce(each.value.name, each.key), "TF_") ? coalesce(each.value.name, each.key) : "TF_${coalesce(each.value.name, each.key)}"
  folder          = coalesce(each.value.folder, var.folder)
  position        = each.value.position
  action          = each.value.action
  from            = each.value.from
  to              = each.value.to
  source          = each.value.source
  destination     = each.value.destination
  source_user     = each.value.source_user
  category        = each.value.category
  application     = each.value.application
  service         = each.value.service
  source_hip      = each.value.source_hip
  destination_hip = each.value.destination_hip
  log_setting     = each.value.log_setting
  log_end         = each.value.log_end
  log_start       = each.value.log_start
  disabled        = each.value.disabled
  description     = each.value.description
  profile_setting = each.value.profile_group != null ? {
    group = [each.value.profile_group]
  } : null
}

# ==============================================================================
# ZERO TRUST NETWORK ACCESS Connector INFRASTRUCTURE & APPLICATIONS
# ==============================================================================

# 1. ZTNA Connector Groups
resource "ztna_connector_group" "group" {
  for_each         = var.ztna_connector_groups
  name             = startswith(each.value.name, "TF_") ? each.value.name : "TF_${each.value.name}"
  description      = each.value.description

  lifecycle {
    create_before_destroy = true
  }
}

# 2. ZTNA Connectors
resource "ztna_connector" "connector" {
  for_each        = var.ztna_connectors
  name            = startswith(each.value.name, "TF_") ? each.value.name : "TF_${each.value.name}"
  group           = try(ztna_connector_group.group[each.value.connector_group].oid, each.value.connector_group)
  description     = each.value.description

  depends_on = [ztna_connector_group.group]
}

# 3. ZTNA FQDN Applications
resource "ztna_fqdn_application" "fqdn_app" {
  for_each         = var.ztna_fqdn_applications
  name             = startswith(each.value.name, "TF_") ? each.value.name : "TF_${each.value.name}"
  description      = each.value.description
  group            = try(ztna_connector_group.group[each.value.connector_groups[0]].oid, each.value.connector_groups[0])
  spec = [{
    fqdn = each.value.fqdn
  }]

  depends_on = [ztna_connector.connector]
}

# 4. ZTNA Subnet Applications
resource "ztna_subnet" "subnet_app" {
  for_each         = var.ztna_subnets
  name             = startswith(each.value.name, "TF_") ? each.value.name : "TF_${each.value.name}"
  description      = each.value.description
  group            = try(ztna_connector_group.group[each.value.connector_groups[0]].oid, each.value.connector_groups[0])
  ip_subnets       = join(", ", each.value.subnets)

  depends_on = [ztna_connector.connector]
}

# 5. ZTNA Wildcard Applications
resource "ztna_wildcard" "wildcard_app" {
  for_each         = var.ztna_wildcards
  name             = startswith(each.value.name, "TF_") ? each.value.name : "TF_${each.value.name}"
  description      = each.value.description
  group            = try(ztna_connector_group.group[each.value.connector_groups[0]].oid, each.value.connector_groups[0])
  fqdn             = each.value.domain

  depends_on = [ztna_connector.connector]
}

# ==============================================================================
# TENANT BOOTSTRAP ACTION (ONE-TIME INITIALIZATION)
# ==============================================================================
# Bootstrap Prisma Access application defaults (certificates, config nodes) on a
# fresh tenant. One-time, tenant-wide, and effectively irreversible — a fresh
# tenant needs this before other automation. Requires Terraform >= 1.14 to invoke.
#
# Usage:
#   terraform apply -invoke=action.scm_application_defaults.bootstrap

action "scm_application_defaults" "bootstrap" {
  config {}
}

# Initiate ZTNA tenant onboarding. This action starts the onboarding process
# for the tenant associated with the authenticated credentials.
#
# Usage:
#   terraform apply -invoke=action.ztna_tenant_start_onboarding.run

action "ztna_tenant_start_onboarding" "run" {
  provider = ztna
  config {}
}