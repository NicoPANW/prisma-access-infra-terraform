# SCM Prisma Access Terraform Automation

This repository contains the Terraform configurations and helper Python scripts to automate deployment of Remote Networks (RN) and Service Connections (SC) on Strata Cloud Manager.

## Prerequisites

1. Copy your credentials file into the root of this project as `auth-token.json`. It must follow this structure:
   ```json
   {
     "client_id": "YOUR_CLIENT_ID",
     "client_secret": "YOUR_CLIENT_SECRET",
     "host": "api.strata.paloaltonetworks.com",
     "protocol": "https",
     "scope": "tsg_id:YOUR_TSG_ID"
   }
   ```
2. Fetch the current SCM cloud compute region map file before planning:
   ```bash
   python3 RN_fetch_cloud_mapping_regions.py
   ```
3. Run `terraform init` and `terraform apply`.