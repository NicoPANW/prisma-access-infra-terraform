# The folder context in SCM where Prisma Access configuration sits
folder = "Shared"
scm_auth_file = "jwt-token.json"

# ==============================================================================
# 1. SERVICE CONNECTION (SC) CONFIGURATION
# ==============================================================================
service_connection = {
  name                 = "Cust2-SC"
  region               = "France South"
  region_tag           = "PA-G"
  subnets              = ["192.168.255.240/32"]
  psk                  = "replace-with-yours"
  ike_gateway_name     = "ike_Gateway_Cust2-SC"
  # References to custom cryptographic profiles managed via Terraform
  ipsec_tunnel_name    = "Cust2-SC1"
  ipsec_crypto_profile = "prod-ipsec-crypto-profile"
  ike_crypto_profile   = "prod-ike-crypto-profile"
  # Peer ID definition matching peer configuration of the remote gateway
  peer_id = {
    id   = "Cust2-SC1@gsat.pro"
    type = "ufqdn"
  }
  # Local tunnel interface binding (e.g., vlan interface)
  local_address = {
    interface = "vlan"
  }
  # Connection established in passive mode waiting for peer to initiate
  passive_mode = true
  tunnel_monitor = {
    enable         = true
    destination_ip = "192.168.255.240"
  }
  # BGP Routing specifications for the SC over the IPSec tunnel
  bgp = {
    enable          = true
    peer_as         = "65528"
    peer_ip_address = "192.168.255.240"
  }
}

# ==============================================================================
# 2. REMOTE NETWORKS (RN) CONFIGURATION (Branch offices, offices, etc.)
# ==============================================================================
remote_networks = {
  "Cust2-RN1" = {
    name                 = "Cust2-RN1"
    region               = "India West"
    subnets              = ["192.168.255.254/32", "10.254.254.254/32"]
    license_type         = "FWAAS-AGGREGATE"
    bandwidth            = 50
    psk                  = "replace-with-yours"
    ike_gateway_name     = "ike_Gateway_Cust2-RN1"
    # Associating tunnels with standard crypto profiles
    ipsec_tunnel_name    = "Cust2-RN1-tunnel"
    ipsec_crypto_profile = "prod-ipsec-crypto-profile"
    ike_crypto_profile   = "prod-ike-crypto-profile"
    peer_id = {
      id   = "Cust2-RN1@gsat.pro"
      type = "ufqdn"
    }
    local_address = {
      interface = "vlan"
    }
    passive_mode = true
    tunnel_monitor = {
      enable         = true
      destination_ip = "10.1.1.1"
    }
    # Active BGP routing configuration for the first remote network
    bgp = {
      enable                  = true
      originate_default_route = true
      peer_ip_address         = "10.1.1.1"
      peer_as                 = "65530"
      local_ip_address        = "10.1.1.2"
      do_not_export_routes    = true
    }
  },
  "Cust2-RN2" = {
    name                 = "Cust2-RN2"
    region               = "Australia Southeast"
    subnets              = ["172.31.0.96/27"]
    license_type         = "FWAAS-AGGREGATE"
    bandwidth            = 50
    psk                  = "replace-with-yours"
    ike_gateway_name     = "ike_Gateway_Cust2-RN2"
    # Tunnel 2 parameters for secondary branch office link
    ipsec_tunnel_name    = "Cust2-RN2-tunnel"
    ipsec_crypto_profile = "prod-ipsec-crypto-profile"
    ike_crypto_profile   = "prod-ike-crypto-profile"
    peer_id = {
      id   = "Cust2-RN2@gsat.pro"
      type = "ufqdn"
    }
    local_address = {
      interface = "vlan"
    }
    passive_mode = true
    tunnel_monitor = {
      enable         = true
      destination_ip = "192.168.255.249"
    }
    # BGP disabled for RN2; routing will rely on static subnet paths
    bgp = {
      enable                  = false
      originate_default_route = false
      peer_ip_address         = ""
      peer_as                 = ""
      local_ip_address        = ""
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
