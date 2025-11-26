# **Troubleshooting & Issues I Ran Into**

During development of the GitHub Actions > Terraform > Azure VM CI/CD workflow, several common Azure and Terraform issues surfaced. These are documented here for reference.

---

#### **1. Resource Provider Registration Errors**

**Error:**

```
InvalidResourceNamespace
Cannot register provider Microsoft.Media / MixedReality / TimeSeriesInsights
```

**Cause:**
Azure free/student subscriptions have many resource providers disabled by default. Terraform tries to auto-register providers when `features {}` is used.

**Fix:**
Disable auto-registration in the provider block.

```hcl
provider "azurerm" {
  features {}
  skip_provider_registration = true
}
```

---

#### **2. Terraform Cannot Find SSH Public Key**

**Error:**

```
Invalid value for "path": no file exists at "~/.ssh/id_rsa.pub"
```

**Cause:**
GitHub Actions runners do not have local user SSH keys. Terraform can only read files that are inside the repository.

**Fix:**
Add `terraform/ssh_key.pub` to the repo and update `main.tf`:

```hcl
public_key = file("${path.module}/ssh_key.pub")
```

Delete the old variable:

```hcl
variable "ssh_public_key_path" { ... }   # removed
```

---

#### **3. Azure Free Tier Public IP Limit**

**Error:**

```
IPv4BasicSkuPublicIpCountLimitReached
Cannot create more than 0 IPv4 Basic SKU public IP addresses
```

**Cause:**
Many free/student Azure subscriptions do **not allow Basic SKU Public IPs** (especially in East US).

**Fix:** Use a **Standard** SKU Public IP:

```hcl
resource "azurerm_public_ip" "public_ip" {
  sku               = "Standard"
  allocation_method = "Static"
}
```

---

#### **4. VM Size Not Available in Region**

**Error:**

```
SkuNotAvailable
Standard_B1s is currently not available in location 'eastus'
```

**Cause:**
Popular regions like East US often run out of low-cost burstable VMs (B-series), especially in free-tier subscriptions.

**Fix:**
Switch to a less congested region and a more available VM size:

```hcl
location = "westus2"
size     = "Standard_B1ls"
```

---

#### **5. Resource Group Already Exists (State Loss)**

**Error:**

```
A resource with the ID ... already exists - to be managed via Terraform this resource needs to be imported...
```

**Cause:**
GitHub Actions runners are **stateless**.
Terraform state was lost between runs, so TF tried to recreate the resource group that was already deployed.

**Fix (short-term):**
Delete the Resource Group manually and re-run.

**Fix (long-term): Use remote Terraform state backend**
(Recommended for all pipelines.)

---

#### **6. Workflow Triggering on README Changes**

**Issue:**
Every small README update triggered a full Azure deployment.

**Fix:**
Add path ignore patterns to the GitHub Actions workflow:

```yaml
on:
  push:
    branches: [ "main" ]
    paths-ignore:
      - README.md
      - "*.md"
      - docs/**
```


# Ansible issues I ran into

## **1. `terraform init` failed due to incompatible flags**

**Error:**

```
The -migrate-state and -reconfigure options are mutually-exclusive.
```

**Cause:**
I was running:

```bash
terraform init -reconfigure -migrate-state -force-copy
```

These arguments cannot be used together.

**Fix:**
Use a clean initialization:

```bash
terraform init
```

---

## **2. Wrong Terraform Output Variable (`public_ip` vs `public_ip_address`)**

**Error:**
GitHub Actions failed with exit 1 when fetching the IP:

```
terraform output -raw public_ip
```

**Cause:**
My actual Terraform output was named:

```hcl
output "public_ip_address" { ... }
```

**Fix:**
Update the workflow:

```bash
terraform output -raw public_ip_address
```

---

## **3. SSH Authentication Failure (`Permission denied (publickey)`)**

**Error:**

```
Permission denied (publickey)
```

**Cause:**
The VM was created using **Terraform’s auto-generated SSH key**, but the workflow was trying to connect with **my custom GitHub secret key**, which Azure does NOT trust.

Azure only accepted the Terraform key injected during VM creation.

**Fix:**
Load the Terraform-generated private key from state:

```bash
PRIVATE_KEY=$(terraform output -raw private_key_pem)
echo "$PRIVATE_KEY" > ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa
```

---

## **4. Build Failed Because Terraform Outputs Were Empty**

**Error:**

```
Error: Failed to retrieve public_ip_address from Terraform state.
```

**Cause:**
Terraform couldn't read remote state until I removed the bad init flags and ensured OIDC login was done before accessing state.

**Fix:**
Ensure workflow order:

1. `azure/login@v2`
2. `setup-terraform`
3. `terraform init`
4. `terraform output -raw`

---

## **5. SSH Not Ready (Cloud-Init Not Finished)**

**Error:**

```
Timed out waiting for SSH
```

**Cause:**
Azure Ubuntu VMs need ~20–60 seconds for cloud-init to finish before SSH is fully ready.

**Fix:**
Add a retry loop:

```bash
for i in {1..12}; do
  if nc -zv "$VM_IP" 22; then exit 0; fi
  sleep 10
done
```

---

## **6. Ansible Inventory Built Before VM_IP Was Exported**

**Symptoms:**

* Inventory had an empty IP
* SSH connection failed
* Ansible ping failed

**Cause:**
The `$VM_IP` env variable wasn’t set until after fixing the Terraform output step.

**Fix:**
Write to GitHub environment correctly:

```bash
echo "VM_IP=$VM_IP_ADDRESS" >> $GITHUB_ENV
```

---

## **7. Inventory Corruption ("got: exited")**

**Error:**

```
Failed to parse inventory: Expected key=value host variable assignment, got: exited
```

**Cause:**
When the `terraform output` command failed (exited with code 1), the shell captured the error message string (e.g., "Error: Terraform exited...") into the `$VM_IP` variable. This error string was then written into `inventory.ini`, creating invalid syntax that Ansible couldn't read.

**Fix:**
Add error checking before writing to the inventory:

```bash
if [ -z "$VM_IP_ADDRESS" ]; then exit 1; fi
```

-----

## **8. Missing Dependencies (Exit Code 127)**

**Error:**

```
line 3: terraform: command not found
Error: Process completed with exit code 127
```

**Cause:**
I accidentally removed the `hashicorp/setup-terraform` and `apt-get install ansible` steps while cleaning up the workflow. GitHub Actions runners are ephemeral (fresh) every time, so tools must be installed on *every* run.

**Fix:**
Restore the installation steps:

```yaml
- uses: hashicorp/setup-terraform@v3
- run: sudo apt-get install -y ansible
```

-----

## **10. SSH Host Key Verification**

**Potential Error:**
(Prevented proactively, but worth noting) The workflow would hang or fail asking to verify the host authenticity:

```
The authenticity of host 'x.x.x.x' can't be established.
Are you sure you want to continue connecting (yes/no)?
```

**Cause:**
The runner is fresh and doesn't know the new VM's SSH fingerprint. In an automated CI/CD environment, we cannot interactively type "yes".

**Fix:**
Disable strict host checking in the Ansible inventory command:

```bash
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

