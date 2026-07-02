# ==============================================================================
# SCM SYSTEM VARIABLES
# ==============================================================================

variable "scm_auth_file" {
  type        = string
  description = "The absolute path to the SCM shared JWT authentication file."
  default     = "jwt-token.json"
}

variable "folder" {
  type        = string
  description = "The folder in SCM where resources will be created (e.g., 'Shared', 'Remote Networks', or 'Service Connections')."
  default     = "Shared"
}

# ==============================================================================
# SERVICE CONNECTION SCHEMA DEFINITION
# ==============================================================================
variable "service_connection" {
  type = object({
    name                 = string
    region               = string
    region_tag           = string
    subnets              = list(string)
    psk                  = string
    ike_gateway_name     = string
    ipsec_tunnel_name    = string
    ipsec_crypto_profile = string
    ike_crypto_profile   = string
    peer_id = object({
      id   = string
      type = string
    })
    local_address = object({
      interface = string
    })
    passive_mode = bool
    tunnel_monitor = object({
      enable         = bool
      destination_ip = string
    })
    bgp = object({
      enable          = bool
      peer_as         = string
      peer_ip_address = string
    })
  })
  description = "Configuration details for the Service Connection."
}

# ==============================================================================
# REMOTE NETWORKS SCHEMA DEFINITION
# ==============================================================================
variable "remote_networks" {
  type = map(object({
    name                 = string
    region               = string
    subnets              = list(string)
    license_type         = string
    bandwidth            = number
    psk                  = string
    ike_gateway_name     = string
    ipsec_tunnel_name    = string
    ipsec_crypto_profile = string
    ike_crypto_profile   = string
    peer_id = object({
      id   = string
      type = string
    })
    local_address = object({
      interface = string
    })
    passive_mode = bool
    tunnel_monitor = object({
      enable         = bool
      destination_ip = string
    })
    bgp = object({
      enable                  = bool
      originate_default_route = bool
      peer_ip_address         = string
      peer_as                 = string
      local_ip_address        = string
      do_not_export_routes    = bool
    })
  }))
  description = "Map of Remote Network configurations dynamically matching customer migration requirements."
}

# ==============================================================================
# Cryptographic Customizations (Defaults to secure production standards)
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