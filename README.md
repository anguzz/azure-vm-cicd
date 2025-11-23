# azure-vm-cicd
Automated Azure VM deployment using GitHub Actions and Infrastructure as Code.



# Setup process

Go to 
https://portal.azure.com/#home


1) Setup an Entra app registration
- Microsoft Entra ID > App registrations > New registration

- `github-azure-vm-cicd`

- `Default directory only - Single tenant`

*For our current use case we do not need Multi-tenant access, Personal Microsoft accounts ,External users, or Redirect URIs*

2) Create a client secret

 - Manage > Certificates & Secrets > New client secret 

 - Name it and add an expiration date.
 `github-cicd-client-secret`

 - Save the Value and secret ID


