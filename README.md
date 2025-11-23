# azure-vm-cicd

Automated Azure VM deployment using GitHub Actions and Infrastructure as Code.

# Directroy structure

```
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
```

# Setup process



### 1) Setup an Entra app registration

Go to https://portal.azure.com/#home

- Microsoft Entra ID > App registrations > New registration

- `github-azure-vm-cicd`

- `Default directory only - Single tenant`

*For our current use case we do not need Multi-tenant access, Personal Microsoft accounts ,External users, or Redirect URIs*

### 2)  Link the App Registration to the Azure Subscription (Assign RBAC Role)

To allow GitHub Actions to deploy Azure resources using OIDC, the App Registration must be granted access to your subscription. 

### **Steps:**

1. Navigate to
   **Home > Subscriptions > *Azure subscription 1***
2. Open
   **Access control (IAM)**
3. Click **Add → Add role assignment**
4. Select the **Contributor** role
5. Click **Next**, then choose:
   **User, group, or service principal**
6. Click **Select members** and search for: `github-azure-vm-cicd`
7. Select it > **Review + assign**

This grants GitHub’s identity permission to create/update Azure resources using Terraform.

![Subscription RBAC](screenshots/subscription.png)



### 2) Enable OIDC Federated Identity

OIDC (OpenID Connect) federated identity is a way for GitHub Actions to log into Azure without using secrets, passwords, or client secrets. It sets up a direct trust between Azure & Github.

Go to  `App registration` > `github-azure-vm-cicd |certifcates & secrets` > `Federated Credentials` > `Add credential`
 

- Federated credential scenario : GitHub Actions deploying Azure resources
- Organization: anguzz
- Repository: azure-vm-cicd
- Entity type: Branch
- GitHub branch name: main
- Credential details: github-oidc-main
- Description: OIDC federated credential for GitHub Actions (main branch) deploying Azure resources.


### 3) Create Azure Storage Account for Remote State

To ensure deployment state is maintained across GitHub Actions runs and to prevent the "resource already exists" error, Terraform state must be stored remotely in a dedicated Azure Storage Account.

**Note:** This Storage Account must be created **manually** or using a separate, one-time Terraform run, as it is a dependency for all subsequent infrastructure deployments.

#### **Steps:**

1.  Navigate to the Azure Portal and create a new **Resource Group** dedicated to state (e.g., `rg-terraform-state`). (Optional, but recommended for clean separation.)
2.  Create a **Storage Account** with a globally unique name (e.g., `anguzzdevopsdemo`) inside this Resource Group.
    * **Account Kind:** General-purpose v2
    * **Performance:** Standard
    * **Redundancy:** LRS (Locally-redundant storage)
3.  Once the Storage Account is created, navigate to the **Containers** blade and create a new container named **`tfstate`**.

This dedicated account is referenced in `terraform/providers.tf` to define the **backend** location.
![tfbackend](screenshots/tfbackend.png)



### 4) Grant Storage Data Access

While the general **Contributor** role allows managing resources, it does **not** grant permission to read or write data *inside* a Storage Account. To allow Terraform to save the state file (`.tfstate`), you must explicitly assign a data-plane role.

**Steps:**

1.  Navigate to the Storage Account you created (e.g., `anguzzdevopsdemo`).
2.  Open **Access control (IAM)** \> **Add role assignment**.
3.  Select the **Storage Blob Data Contributor** role.
4.  Assign it to your App Registration: `github-azure-vm-cicd`.


![storageBlobCon](screenshots/storageBlobCon.png)

### 5) Create github actions and add secrets
- Under the repo goto `settings`
- Go to `secrets & variables` > `actions`
- New Secret
- Add the secrets and the corresponding values in `.env-example`

It should look something like this:
![secrets.png](screenshots/secrets.png)




### 6) Create github action workflow.

The GitHub Actions workflow I created in `.github/workflows/deploy.yml` runs Terraform against the files in the `terraform/` folder:


#### Terraform Overview

- **main.tf** – defines all Azure resources (resource group, network, public IP, NIC, and the Ubuntu VM).
- **variables.tf** – holds input values such as VM name, region, size, admin username, and SSH key path. You can customize these.
- **outputs.tf** – prints useful information after deployment, such as the VM’s public IP.

Terraform will automatically create any resources that do not already exist (including the Resource Group). GitHub Actions handles the deployment by running `terraform init`, `plan`, and `apply` on each push to `main`.



### 7) Add SSH Key to Terraform

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



## Redeploying the VM

To redeploy the VM at any time, go to:

```
GitHub > Actions > Deploy Azure VM > Run workflow
```

This will:

* Force a full redeploy
* Apply any new Terraform changes
* Recreate the VM if it was deleted in Azure
* Ensure the VM always matches the state defined in code

I plan to also also extend this project by adding additional workflows under `.github/workflows/` — for example:

* A `destroy.yml` workflow to tear down the environment
* A workflow that deploys multiple VMs at once
* A workflow that triggers Ansible for post-configuration

This adds functionality the repository into a reusable CI/CD-driven Infrastructure-as-Code automation pipeline.


# Resources
https://learn.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-terraform

https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/public-ip-addresses#limitations

https://learn.microsoft.com/en-us/azure/virtual-machines/linux/quick-create-terraform?tabs=azure-cli

https://learn.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-terraform?tabs=azure-cli 