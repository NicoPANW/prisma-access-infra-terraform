# The folder context in SCM where Prisma Access configuration sits
folder = "Shared"
scm_auth_file = "jwt-token.json"


/*
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
    region_tag                   = "PA-G"
    subnets                      = ["10.0.0.0/24"]
    local_address_interface      = "vlan"
    passive_mode                 = true

    # Primary Tunnel Details
    primary_ike_gateway_name     = "ike_Gateway_1783082716072"
    primary_peer_address         = "1.2.3.4"
    primary_psk                  = "replace-with-yours"
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
    secondary_psk                  = "replace-with-yours"
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
*/

/*
# ==============================================================================
# 2. REMOTE NETWORKS (RN) CONFIGURATION (Branch offices, etc.)
# ==============================================================================

remote_networks = {
  "Cust2-RN1-single-tunnel-BGP-AggBW" = {
    name                 = "Cust2-RN1-single-tunnel-BGP-AggBW"
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
  "Cust2-RN2-single-tunnel-static-AggBW" = {
    name                 = "Cust2-RN2-single-tunnel-static-AggBW"
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
  "Cust2-RN3-dual-tunnel-BGP-AggBW" = {
    name                 = "Cust2-RN3-dual-tunnel-BGP-AggBW"
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
  },
  "Cust2-RN4-site-branch" = {
    name                         = "Cust2-RN4-site-branch"
    region                       = "France North"
    license_type                 = "FWAAS-SITE-250Mbps"
    local_address_interface      = "vlan"
    passive_mode                 = true

    primary_ike_gateway_name     = "ike_Gateway_RN4_Site"
    primary_peer_address         = "1.1.1.1"
    primary_psk                  = "replace-with-yours"
    primary_ike_crypto_profile   = "TF_prod-ike-crypto-profile"
    primary_ipsec_tunnel_name    = "RN4-Site-Tunnel"
    primary_ipsec_crypto_profile = "TF_prod-ipsec-crypto-profile"
    primary_peer_id = {
      type = "ipaddr"
      id   = "1.1.1.1"
    }
    primary_tunnel_monitor_ip    = "192.168.10.1"

    bgp = {
      enable                  = true
      originate_default_route = true
      peer_ip_address         = "192.168.10.1"
      peer_as                 = "65531"
      local_ip_address        = "192.168.10.2"
      do_not_export_routes    = true
    }

    # Site configuration linking this Remote Network as an active member
    site = {
      name         = "Cust2-RN4-site-branch-single"
      type         = "third-party-branch"
      license_type = "FWAAS-SITE-250Mbps"
      city         = "Paris"
      country      = "France"
      zip_code     = "95135"
      latitude     = "48.8575475"
      longitude    = "2.3513765"
      mode         = "active"
      qos = {
        profile = "Default Profile"
        cir     = 200
      }
    }
  },
  "Cust2-RN5-site-branch" = {
    name                         = "Cust2-RN5-site-branch"
    region                       = "France North"
    license_type                 = "FWAAS-SITE-250Mbps"
    ecmp_load_balancing          = "disable"
    local_address_interface      = "vlan"
    passive_mode                 = true

    primary_ike_gateway_name     = "ike_gw_ping_test"
    primary_peer_address         = "1.1.1.1"
    primary_psk                  = "replace-with-yours"
    primary_ike_crypto_profile   = "TF_prod-ike-crypto-profile"
    primary_ipsec_tunnel_name    = "testipsec"
    primary_ipsec_crypto_profile = "TF_prod-ipsec-crypto-profile"
    primary_peer_id = {
      type = "ipaddr"
      id   = "1.1.1.1"
    }
    primary_tunnel_monitor_ip    = "10.44.55.10"

    bgp = {
      enable                  = true
      originate_default_route = true
      peer_ip_address         = "10.44.55.10"
      peer_as                 = "65529"
      local_ip_address        = "10.44.55.11"
      do_not_export_routes    = true
    }

    site = {
      name                  = "Cust2-RN5-site-branch-dual"
      type                  = "third-party-branch"
      license_type          = "FWAAS-SITE-250Mbps"
      city                  = "paris"
      country               = "France"
      latitude              = "48.8575475"
      longitude             = "2.3513765"
      mode                  = "active"
      backup_remote_network = "Cust2-RN5-site-branch_backup"
      qos = {
        profile = "Default Profile"
        cir     = 2
      }
    }
  },
  "Cust2-RN5-site-branch_backup" = {
    name                         = "Cust2-RN5-site-branch_backup"
    region                       = "Belgium"
    license_type                 = "FWAAS-SITE-250Mbps"
    ecmp_load_balancing          = "disable"
    local_address_interface      = "vlan"
    passive_mode                 = true

    primary_ike_gateway_name     = "ike_gw_ping_test_backup"
    primary_peer_address         = "1.1.1.2"
    primary_psk                  = "replace-with-yours"
    primary_ike_crypto_profile   = "TF_prod-ike-crypto-profile"
    primary_ipsec_tunnel_name    = "testipsec_backup"
    primary_ipsec_crypto_profile = "TF_prod-ipsec-crypto-profile"
    primary_peer_id = {
      type = "ipaddr"
      id   = "1.1.1.2"
    }
    primary_tunnel_monitor_ip    = "10.44.55.10"

    bgp = {
      enable                  = true
      originate_default_route = true
      peer_ip_address         = "10.44.55.10"
      peer_as                 = "65529"
      local_ip_address        = "10.44.55.11"
      do_not_export_routes    = true
    }
  }
}
*/

/*
# ==============================================================================
# 3. ZERO TRUST NETWORK ACCESS Connector CONFIGURATION
# ==============================================================================
ztna_x_panw_region = "americas"

ztna_connector_groups = {
  "internal-apps-group" = {
    name             = "internal-apps-group"
    description      = "Primary connector group for internal corporate apps"
  }
}

ztna_connectors = {
  "connector-vm-01" = {
    name            = "connector-vm-01"
    connector_group = "internal-apps-group"
    description     = "Primary on-prem ZTNA connector VM"
  }
}

ztna_fqdn_applications = {
  "jira-internal" = {
    name             = "jira-internal"
    fqdn             = "jira.corp.internal"
    connector_groups = ["internal-apps-group"]
    description      = "Internal Jira ticketing service"
  }
}

ztna_subnets = {
  "corp-dc-subnet" = {
    name             = "corp-dc-subnet"
    subnets          = ["10.50.0.0/16"]
    connector_groups = ["internal-apps-group"]
    description      = "Datacenter server subnet"
  }
}

ztna_wildcards = {}
*/

# ==============================================================================
# 4. SECURITY RULES CONFIGURATION
# ==============================================================================
security_rules = {
  "Secure Internet Access - cust2" = {
    position      = "pre"
    action        = "allow"
    from          = ["trust"]
    to            = ["any"]
    source        = ["any"]
    destination   = ["any"]
    application   = ["any"]
    service       = ["any"]
    profile_group = "best-practice"
    description   = "Secure Internet Access - cust2.  changing description to test config logs. Demo"
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
