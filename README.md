## Getting Started
1. Create IAM Service Principle w/ necessary permissions and secret key
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret#creating-a-service-principal-using-the-azure-cli

2. Create Azure Key Vault and Secrets. Give read permissions to the service principle created in above step.
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret
   - vmadminpw = "Pa$$word!"
    - vpnsharedkey = "Pa$$word!"
   - gatewayaddress = "onpremgatewayaddress" ## ex) "93.2.43.42"

1. Add environment variables to GitLab CI/CD
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret#configuring-the-service-principal-in-terraform

4. Clone repository an edit subnets to fit your environment.

5. Configure on-premise vpn device and verify connectivity.

## Documentation
[Cloud C2 Docs](https://docs.hak5.org/cloud-c2/getting-started/installation-and-setup)
[Cloud C2 Video](https://www.youtube.com/watch?v=rgmL75ZBfSI https://www.youtube.com/watch?v=TIpx_ENurLY)
