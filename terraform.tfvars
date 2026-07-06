# The folder context in SCM where Prisma Access configuration sits
folder = "Shared"
scm_auth_file = "jwt-token.json"

# ==============================================================================
# 1. SERVICE CONNECTION (SC) CONFIGURATION
# ==============================================================================
service_connections = {
  "Cust2-SC-single-tunnel-BGP" = {
    name                         = "Cust2-SC-single-tunnel-BGP"
    region                       = "France South"
    region_tag                   = "PA-G"
    subnets                      = ["192.168.255.240/32"]
    local_address_interface      = "vlan"
    passive_mode                 = true

    #it is dynamic tunnel, so no peer IP
    primary_ike_gateway_name     = "ike_Gateway_Cust2-SC"
    primary_psk                  = "replace-with-yours"
    primary_ike_crypto_profile   = "TF_prod-ike-crypto-profile"
    primary_ipsec_tunnel_name    = "Cust2-SC1"
    primary_ipsec_crypto_profile = "TF_prod-ipsec-crypto-profile"

    primary_peer_id = {
      id   = "Cust2-SC1@gsat.pro"
      type = "ufqdn"
    }
    primary_tunnel_monitor_ip    = "192.168.255.240"

    protocol = {
      bgp = {
        enable          = true
        peer_as         = "65528"
        peer_ip_address = "192.168.255.240"
      }
    }
  },
  "Cust2-SC-dual-tunnel-BGP" = {
    name                         = "Cust2-SC-dual-tunnel-BGP"
    region                       = "Canada Central"
    region_tag                   = "PA-O"
    subnets                      = ["10.0.0.0/24"]
    local_address_interface      = "vlan"
    passive_mode                 = true

    # Primary Tunnel Details
    primary_ike_gateway_name     = "ike_Gateway_1783082716072"
    primary_peer_address         = "1.2.3.4"
    primary_psk                  = "-AQ==cRDtpNCeBiql5KOQsKVyrA0sAiA=0131GnEFDCtKt7/WuBN22Q=="
    primary_ike_crypto_profile   = "Others-IKE-Crypto-Default"
    primary_ipsec_tunnel_name    = "Primary"
    primary_ipsec_crypto_profile = "Others-IPSec-Crypto-Default"
    primary_local_id = {
      type = "fqdn"
      id   = "sase-rocks"
    }
    primary_peer_id = {
      type = "ipaddr"
      id   = "1.2.3.4"
    }
    primary_tunnel_monitor_ip    = "10.0.0.250"

    # Secondary Tunnel Details
    enable_secondary               = true
    secondary_ike_gateway_name     = "ike_Gateway_1783082845194"
    secondary_peer_address         = "4.5.6.7"
    secondary_psk                  = "-AQ==5i01FiUuVfdK9TZuXTCdieT68fI=Khfpt2jBQuxYqRn+h664fQ=="
    secondary_ike_crypto_profile   = "PaloAlto-Networks-IKE-Crypto"
    secondary_ipsec_tunnel_name    = "Secondary"
    secondary_ipsec_crypto_profile = "PaloAlto-Networks-IPSec-Crypto"
    secondary_local_id = {
      type = "fqdn"
      id   = "sase-power"
    }
    secondary_peer_id = {
      type = "ipaddr"
      id   = "4.5.6.7"
    }
    secondary_tunnel_monitor_ip    = "10.0.0.251"

    bgp_peer = {
      enable           = true
      same_as_primary  = false
      peer_ip_address  = "10.0.0.251"
      local_ip_address = "10.0.0.2"
    }

    protocol = {
      bgp = {
        enable           = true
        peer_ip_address  = "10.0.0.250"
        peer_as          = "64555"
        local_ip_address = "10.0.0.1"
      }
    }
  }
}

# ==============================================================================
# 2. REMOTE NETWORKS (RN) CONFIGURATION (Branch offices, etc.)
# ==============================================================================
remote_networks = {
  "Cust2-RN1-single-tunnel-BGP" = {
    name                 = "Cust2-RN1-single-tunnel-BGP"
    region               = "India West"
    subnets              = ["192.168.255.254/32", "10.254.254.254/32"]
    license_type         = "FWAAS-AGGREGATE"
    bandwidth            = 50
    local_address_interface      = "vlan"
    passive_mode                 = true

    #it is dynamic tunnel, so no peer IP
    primary_ike_gateway_name     = "ike_Gateway_Cust2-RN1"
    primary_psk                  = "replace-with-yours"
    primary_ike_crypto_profile   = "TF_prod-ike-crypto-profile"
    primary_ipsec_tunnel_name    = "Cust2-RN1-tunnel"
    primary_ipsec_crypto_profile = "TF_prod-ipsec-crypto-profile"
    primary_peer_id = {
      id   = "Cust2-RN1@gsat.pro"
      type = "ufqdn"
    }
    primary_tunnel_monitor_ip    = "10.1.1.1"

    bgp = {
      enable                  = true
      originate_default_route = true
      peer_ip_address         = "10.1.1.1"
      peer_as                 = "65530"
      local_ip_address        = "10.1.1.2"
      do_not_export_routes    = true
    }
  },
  "Cust2-RN2-single-tunnel-static" = {
    name                 = "Cust2-RN2-single-tunnel-static"
    region               = "Australia Southeast"
    subnets              = ["172.31.0.96/27"]
    license_type         = "FWAAS-AGGREGATE"
    bandwidth            = 50
    local_address_interface      = "vlan"
    passive_mode                 = true

    #it is dynamic tunnel, so no peer IP
    primary_ike_gateway_name     = "ike_Gateway_Cust2-RN2"
    primary_psk                  = "replace-with-yours"
    primary_ike_crypto_profile   = "TF_prod-ike-crypto-profile"
    primary_ipsec_tunnel_name    = "Cust2-RN2-tunnel"
    primary_ipsec_crypto_profile = "TF_prod-ipsec-crypto-profile"
    primary_peer_id = {
      id   = "Cust2-RN2@gsat.pro"
      type = "ufqdn"
    }
    primary_tunnel_monitor_ip    = "192.168.255.249"

    bgp = {
      enable                  = false
      originate_default_route = false
      peer_ip_address         = ""
      peer_as                 = ""
      local_ip_address        = ""
      do_not_export_routes    = false
    }
  },
  "Cust2-RN3-dual-tunnel-BGP" = {
    name                 = "Cust2-RN3-dual-tunnel-BGP"
    region               = "Canada Central"
    subnets              = ["10.200.0.0/24"]
    license_type         = "FWAAS-AGGREGATE"
    bandwidth            = 50
    local_address_interface      = "vlan"
    passive_mode                 = true

    

    # Primary Tunnel Details
    primary_ike_gateway_name     = "ike_Gateway_RN3_Primary"
    primary_peer_address         = "9.8.7.6"
    primary_psk                  = "-AQ==cRDtpNCeBiql5KOQsKVyrA0sAiA=0131GnEFDCtKt7/WuBN22Q=="
    primary_ike_crypto_profile   = "TF_prod-ike-crypto-profile"
    primary_ipsec_tunnel_name    = "RN3-Primary-Tunnel"
    primary_ipsec_crypto_profile = "TF_prod-ipsec-crypto-profile"
    primary_local_id = {
      type = "fqdn"
      id   = "rn3-primary-rocks"
    }
    primary_peer_id = {
      type = "ipaddr"
      id   = "9.8.7.6"
    }
    primary_tunnel_monitor_ip    = "10.200.0.250"

    # Secondary Tunnel Details
    enable_secondary               = true
    secondary_ike_gateway_name     = "ike_Gateway_RN3_Secondary"
    secondary_peer_address         = "7.7.7.7"
    secondary_psk                  = "-AQ==5i01FiUuVfdK9TZuXTCdieT68fI=Khfpt2jBQuxYqRn+h664fQ=="
    secondary_ike_crypto_profile   = "TF_prod-ike-crypto-profile"
    secondary_ipsec_tunnel_name    = "RN3-Secondary-Tunnel"
    secondary_ipsec_crypto_profile = "TF_prod-ipsec-crypto-profile"
    secondary_local_id = {
      type = "fqdn"
      id   = "rn3-secondary-power"
    }
    secondary_peer_id = {
      type = "ipaddr"
      id   = "7.7.7.7"
    }
    secondary_tunnel_monitor_ip    = "10.200.0.251"

    bgp_peer = {
      enable           = true
      same_as_primary  = false
      peer_as          = "64555"
      peer_ip_address  = "10.200.0.251"
      local_ip_address = "10.200.0.2"
    }

    bgp = {
      enable                  = true
      originate_default_route = true
      peer_ip_address         = "10.200.0.250"
      peer_as                 = "64555"
      local_ip_address        = "10.200.0.1"
      do_not_export_routes    = false
    }
  }
}

# ==============================================================================
# CRYPTOGRAPHIC CUSTOMIZATIONS (Global parameters for secure handshakes)
# ==============================================================================
ike_crypto_profile = {
  name       = "prod-ike-crypto-profile"
  dh_group   = ["group20"]
  encryption = ["aes-256-cbc"]
  hash       = ["sha384"]
}

ipsec_crypto_profile = {
  name           = "prod-ipsec-crypto-profile"
  dh_group       = "group20"
  encryption     = ["aes-256-gcm"]
  authentication = ["none"]
}
