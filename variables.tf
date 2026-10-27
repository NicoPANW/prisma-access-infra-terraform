# ==============================================================================
# SCM SYSTEM VARIABLES
# 
# These variables define the system-level parameters required to authenticate
# and scope resources within the Palo Alto Networks Strata Cloud Manager (SCM).
# ==============================================================================

variable "scm_auth_file" {
  type        = string
  description = "The absolute path to the SCM shared JWT authentication file."
  default     = "/Users/nmarcoux/Documents/VS code/customer2-terraform/auth-token.json"
}

variable "folder" {
  type        = string
  description = "The folder in SCM where resources will be created (e.g., 'Shared', 'Remote Networks', or 'Service Connections')."
  default     = "Shared"
}

# ==============================================================================
# SERVICE CONNECTION SCHEMA DEFINITION
# 
# Defines the structural schema for Service Connections (SC). This configuration
# supports both standard single-tunnel and dual-tunnel High-Availability (HA)
# deployments with nested BGP routing parameters.
# ==============================================================================
variable "service_connections" {
  type = map(object({
    name                 = string
    region               = string
    region_tag           = string
    subnets              = list(string)
    
    # Primary Tunnel Configurations
    primary_ike_gateway_name     = string
    primary_peer_address         = optional(string)
    primary_psk                  = string
    primary_ike_crypto_profile   = string
    primary_ipsec_tunnel_name    = string
    primary_ipsec_crypto_profile = string
    primary_local_id             = optional(object({ type = string, id = string }))
    primary_peer_id              = object({ type = string, id = string })
    primary_tunnel_monitor_ip    = string

    # Secondary Tunnel Configurations (Optional for HA)
    enable_secondary               = optional(bool, false)
    secondary_ike_gateway_name     = optional(string)
    secondary_peer_address         = optional(string, null)
    secondary_psk                  = optional(string)
    secondary_ike_crypto_profile   = optional(string)
    secondary_ipsec_tunnel_name    = optional(string)
    secondary_ipsec_crypto_profile = optional(string)
    secondary_local_id             = optional(object({ type = string, id = string }))
    secondary_peer_id              = optional(object({ type = string, id = string }))
    secondary_tunnel_monitor_ip    = optional(string)

    local_address_interface = string
    passive_mode            = bool

    bgp_peer = optional(object({
      enable           = optional(bool, true)
      same_as_primary  = optional(bool, false)
      peer_ip_address  = string
      local_ip_address = string
    }))

    protocol = object({
      bgp = object({
        enable           = bool
        peer_as          = string
        peer_ip_address  = string
        local_ip_address = optional(string)
      })
    })
  }))
  description = "Configuration details for the Service Connection."
  default     = {}
}

# ==============================================================================
# REMOTE NETWORKS SCHEMA DEFINITION
# 
# Defines the structural schema for Remote Networks (RN). Supports bandwidth
# consolidation, custom IKE local/peer IDs, and optional secondary HA tunnels
# with sibling BGP peering definitions.
# ==============================================================================
variable "remote_networks" {
  type = map(object({
    name                 = string
    region               = string
    subnets              = optional(list(string))
    license_type         = string
    bandwidth            = optional(number)
    spn_name             = optional(string)
    ecmp_load_balancing  = optional(string)

    # Primary Tunnel Configurations
    primary_ike_gateway_name     = string
    primary_peer_address         = optional(string)
    primary_psk                  = string
    primary_ike_crypto_profile   = string
    primary_ipsec_tunnel_name    = string
    primary_ipsec_crypto_profile = string
    primary_local_id             = optional(object({ type = string, id = string }))
    primary_peer_id              = object({ type = string, id = string })
    primary_tunnel_monitor_ip    = string

    # Secondary Tunnel Configurations (Optional for HA)
    enable_secondary               = optional(bool, false)
    secondary_ike_gateway_name     = optional(string)
    secondary_peer_address         = optional(string, null)
    secondary_psk                  = optional(string)
    secondary_ike_crypto_profile   = optional(string)
    secondary_ipsec_tunnel_name    = optional(string)
    secondary_ipsec_crypto_profile = optional(string)
    secondary_local_id             = optional(object({ type = string, id = string }))
    secondary_peer_id              = optional(object({ type = string, id = string }))
    secondary_tunnel_monitor_ip    = optional(string)

    local_address_interface = string
    passive_mode            = bool

    bgp = object({
      enable                  = bool
      originate_default_route = optional(bool, false)
      peer_ip_address         = string
      peer_as                 = string
      local_ip_address        = string
      do_not_export_routes    = optional(bool, false)
    })
    bgp_peer = optional(object({
      enable           = optional(bool, true)
      same_as_primary  = optional(bool, false)
      peer_as          = optional(string)
      peer_ip_address  = string
      local_ip_address = string
      secret           = optional(string)
    }))

    # Optional Site configuration wrapper
    site = optional(object({
      name         = string
      type         = optional(string, "third-party-branch")
      license_type = string # e.g. "FWAAS-SITE-25Mbps", "FWAAS-SITE-50Mbps"
      city         = optional(string)
      state        = optional(string)
      country      = optional(string)
      zip_code     = optional(string)
      latitude     = optional(string)
      longitude    = optional(string)
      mode         = optional(string, "active")
      backup_remote_network = optional(string)
      qos = optional(object({
        profile = string
        cir     = number
      }))
    }))
  }))
  description = "Map of Remote Network configurations dynamically matching customer migration requirements."
  default     = {}
}

# ==============================================================================
# ZTNA SYSTEM VARIABLES
# ==============================================================================
variable "ztna_host" {
  type        = string
  description = "Target API endpoint host for ZTNA resources."
  default     = "api.sase.paloaltonetworks.com"
}

variable "ztna_x_panw_region" {
  type        = string
  description = "Region code for the x-panw-region HTTP header (e.g. americas, europe, fr, de, etc.)."
  default     = "fr"
}

# ==============================================================================
# ZTNA Connector SCHEMA DEFINITIONS
# ==============================================================================

variable "ztna_connector_groups" {
  type = map(object({
    name             = string
    description      = optional(string)
  }))
  description = "Map of ZTNA Connector Groups."
  default     = {}
}

variable "ztna_connectors" {
  type = map(object({
    name            = string
    connector_group = string
    description     = optional(string)
  }))
  description = "Map of individual ZTNA Connectors assigned to groups."
  default     = {}
}

variable "ztna_fqdn_applications" {
  type = map(object({
    name             = string
    fqdn             = string
    connector_groups = list(string)
    description      = optional(string)
  }))
  description = "Map of ZTNA FQDN Private Applications."
  default     = {}
}

variable "ztna_subnets" {
  type = map(object({
    name             = string
    subnets          = list(string)
    connector_groups = list(string)
    description      = optional(string)
  }))
  description = "Map of ZTNA Subnet-based Private Applications."
  default     = {}
}

variable "ztna_wildcards" {
  type = map(object({
    name             = string
    domain           = string
    connector_groups = list(string)
    description      = optional(string)
  }))
  description = "Map of ZTNA Wildcard Domain Applications."
  default     = {}
}

# ==============================================================================
# SECURITY RULES SCHEMA DEFINITION
# ==============================================================================
variable "security_rules" {
  type = map(object({
    name            = optional(string)
    folder          = optional(string)
    position        = optional(string, "pre")
    action          = optional(string, "allow")
    from            = optional(list(string), ["trust"])
    to              = optional(list(string), ["any"])
    source          = optional(list(string), ["any"])
    destination     = optional(list(string), ["any"])
    source_user     = optional(list(string), ["any"])
    category        = optional(list(string), ["any"])
    application     = optional(list(string), ["any"])
    service         = optional(list(string), ["any"])
    source_hip      = optional(list(string), ["any"])
    destination_hip = optional(list(string), ["any"])
    log_setting     = optional(string, "Cortex Data Lake")
    log_end         = optional(bool, true)
    log_start       = optional(bool, false)
    disabled        = optional(bool, false)
    description     = optional(string)
    profile_group   = optional(string, "best-practice")
  }))
  description = "Map of SCM Security Rules."
  default     = {}
}

# ==============================================================================
# Cryptographic Customizations (Defaults to secure production standards)
# 
# Custom crypto profiles reference these variables to align VPN negotiation.
# ==============================================================================
variable "ike_crypto_profile" {
  type = object({
    name       = string
    dh_group   = list(string)
    encryption = list(string)
    hash       = list(string)
  })
  description = "Production-grade IKE Cryptographic Profile settings."
}

variable "ipsec_crypto_profile" {
  type = object({
    name       = string
    dh_group   = string
    encryption = list(string)
    authentication = list(string)
  })
  description = "Production-grade IPSec Cryptographic Profile settings."
}