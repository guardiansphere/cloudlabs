# Basic VM Lab

This Terraform configuration provisions a simple Windows virtual machine in Azure for attack/defense exercises.

## Resources Created
- Resource group
- Virtual network and subnet
- Network security group allowing RDP (port 3389)
- Public IP and network interface
- Windows Server 2022 VM

## Usage
1. Install [Terraform](https://terraform.io/) and the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli).
2. Authenticate with Azure using `az login`.
3. Initialize and apply the configuration:
   ```bash
   terraform init
   terraform apply -var="admin_username=<user>" -var="admin_password=<password>"
   ```
4. After use, destroy the environment with `terraform destroy`.

**Estimated cost**: Running this lab should cost under ~$1/day when using a B-series VM. Remember to destroy resources when finished.
