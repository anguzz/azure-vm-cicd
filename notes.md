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

