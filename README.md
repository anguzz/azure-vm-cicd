# azure-vm-cicd

Automated Azure VM deployment using GitHub Actions and Infrastructure as Code.

# Directroy structure
root/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ansible/ (future enhancment)
│   ├── inventory.ini
│   └── configure.yml
├── .gitignore
├── README.md
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


3) Create github actions and add secrets
- Under the repo goto `settings`
- Go to `secrets & variables` > `actions`
- New Secret
- Add the secrets and the corresponding values in `.env-example`

It should look something like this:
![secrets.png](screenshots/secrets.png)

4) Create github action workflow.

The GitHub Actions workflow I created in `.github/workflows/deploy.yml` runs Terraform against the files in the `terraform/` folder:


### Terraform Overview

- **main.tf** – defines all Azure resources (resource group, network, public IP, NIC, and the Ubuntu VM).
- **variables.tf** – holds input values such as VM name, region, size, admin username, and SSH key path. You can customize these.
- **outputs.tf** – prints useful information after deployment, such as the VM’s public IP.

Terraform will automatically create any resources that do not already exist (including the Resource Group). GitHub Actions handles the deployment by running `terraform init`, `plan`, and `apply` on each push to `main`.



5) Add SSH Key to Terraform**

Terraform needs an SSH **public** key so that *you* can SSH into the VM after it’s created. I happened to generate my key on a Windows machine, but the process works the same on Linux or macOS but the commands might differ a tadbit.

Generate the keypair:

```powershell
C:\Users\Angel> ssh-keygen -t rsa -b 4096
Generating public/private rsa key pair.
```

After it finishes, verify and copy your **public** key:

Note: On a linux machine use `cat` rather then `type` 

```powershell
type C:\Users\Angel\.ssh\id_rsa.pub
ssh-rsa AAAAB3N.....
```

Create a file in your repo:

```
terraform/ssh_key.pub
```

Paste the entire `ssh-rsa ...` line into it.

The **public** key is safe to commit it does not grant access by itself without the private key.

Terraform references this public key inside `main.tf`:

```terraform
admin_ssh_key {
  username   = var.admin_username
  public_key = file(var.ssh_public_key_path)
}
```

This ensures Azure injects your SSH public key into the VM so you can SSH later with your private key.
