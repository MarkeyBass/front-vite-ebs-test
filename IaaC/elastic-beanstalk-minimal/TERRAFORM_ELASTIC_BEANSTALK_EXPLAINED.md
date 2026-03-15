# Minimal Terraform for Elastic Beanstalk (Explained)

This folder gives you a minimal, destroy-friendly Elastic Beanstalk setup:

- `main.tf` - provider, IAM roles, EB application/environment, and deployment S3 bucket
- `variables.tf` - configurable inputs
- `outputs.tf` - important values after apply

The main goal is exactly what you asked for: create quickly and remove cleanly when done.

---

## Why Terraform Here

For temporary learning environments, Terraform is useful because:

1. You can create all resources with `terraform apply`.
2. You can remove all managed resources with `terraform destroy`.
3. The desired infra lives in code, not memory or console clicks.

---

## How `main.tf` is Structured

## 1) Terraform and provider blocks

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

- Pins Terraform/provider compatibility.
- Uses `var.aws_region` so region stays configurable.

---

## 2) Common tags

```hcl
locals {
  common_tags = merge(
    {
      Project     = var.project_name
      ManagedBy   = "terraform"
      Environment = var.environment_name
    },
    var.tags
  )
}
```

- Creates one reusable tag map.
- Makes cost tracking and cleanup easier.

---

## 3) Deployment S3 bucket (with force delete)

This project now manages a dedicated artifacts bucket for EB uploads:

```hcl
data "aws_caller_identity" "current" {}

locals {
  deployment_bucket_name = var.deployment_bucket_name != "" ? var.deployment_bucket_name : "${var.project_name}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-eb-artifacts"
}

resource "aws_s3_bucket" "deployment_artifacts" {
  bucket        = local.deployment_bucket_name
  force_destroy = var.deployment_bucket_force_destroy
  tags          = local.common_tags
}
```

What this gives you:

- Auto-generated unique bucket name per account/region (unless you set one manually).
- Optional one-command cleanup when `deployment_bucket_force_destroy = true`.
- Better ownership than relying on shared/default EB buckets.

Security hardening is also applied:

- `aws_s3_bucket_public_access_block` blocks public ACLs/policies.

---

## 4) Auto-select latest Docker solution stack

```hcl
data "aws_elastic_beanstalk_solution_stack" "docker" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux (.*) running Docker$"
}
```

Why this is useful:

- You avoid hardcoding an old stack name that may be deprecated later.
- Terraform picks the newest stack matching that pattern.

This data source pattern comes from AWS provider docs via Context7.

---

## 5) IAM for EC2 instances in your environment

Your Beanstalk EC2 instances need an instance profile + role.

You create:

- `aws_iam_role.eb_ec2_role` (trusted by `ec2.amazonaws.com`)
- `aws_iam_instance_profile.eb_ec2_profile`
- policy attachments:
  - `AWSElasticBeanstalkWebTier`
  - `AWSElasticBeanstalkWorkerTier`
  - `AWSElasticBeanstalkMulticontainerDocker`

Why:

- Beanstalk instances need permissions for app runtime operations and platform integrations.

---

## 6) IAM service role for Elastic Beanstalk service itself

You also create:

- `aws_iam_role.eb_service_role` (trusted by `elasticbeanstalk.amazonaws.com`)
- policy attachments:
  - `arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth`
  - `arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy`

Why:

- Beanstalk service uses this role to manage health and updates.

---

## 7) Elastic Beanstalk application and environment

```hcl
resource "aws_elastic_beanstalk_application" "this" {
  name        = var.project_name
  description = "Elastic Beanstalk app managed by Terraform"
  tags        = local.common_tags
}
```

- Creates the app container (logical application in EB).

```hcl
resource "aws_elastic_beanstalk_environment" "this" {
  name                = var.environment_name
  application         = aws_elastic_beanstalk_application.this.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.docker.name
  tier                = "WebServer"
  ...
}
```

- Creates the runnable environment.
- Uses the latest Docker solution stack from the data source.

Option settings used:

- `EnvironmentType = SingleInstance` (cheaper than load-balanced)
- `InstanceType = var.instance_type` (default `t3.micro`)
- `IamInstanceProfile = aws_iam_instance_profile.eb_ec2_profile.name`
- `ServiceRole = aws_iam_role.eb_service_role.arn`

---

## 8) Outputs

`outputs.tf` returns:

- app name
- environment name
- environment CNAME URL
- selected solution stack name
- deployment bucket name

So after `apply` you can immediately see where to test.

Use `deployment_bucket_name` output in your GitHub Actions workflow:

- `.github/workflows/deploy.yaml`
- `existing_bucket_name: <deployment_bucket_name output>`

---

## 9) Variables and what to change first

In `variables.tf`, the fastest things to customize are:

- `project_name`
- `environment_name`
- `aws_region`
- `instance_type`
- `deployment_bucket_name` (optional override)
- `deployment_bucket_force_destroy` (set true for one-command sandbox cleanup)
- `tags`

Defaults are set to be friendly for a demo/sandbox.

---

## 10) How to run it

From the folder `IaaC/elastic-beanstalk-minimal`:

```bash
AWS_PROFILE=terraform-2026 terraform init
AWS_PROFILE=terraform-2026 terraform plan
AWS_PROFILE=terraform-2026 terraform apply
```

When finished and you want to remove everything:

```bash
AWS_PROFILE=terraform-2026 terraform destroy
```

---

## 11) Important cleanup and safety notes

1. Destroy removes only resources tracked in Terraform state.
2. If you manually change resources in console, destroy can become messy (drift).
3. Always verify no extra manually-created resources remain in AWS after destroy.
4. For team/shared usage, store Terraform state remotely (S3 + DynamoDB lock).

Also keep region/account alignment consistent:

- `terraform.tfvars` currently uses `aws_region = "us-west-2"`.
- `.github/workflows/deploy.yaml` must use the same region.
- `existing_bucket_name` in GitHub Actions should be the Terraform output `deployment_bucket_name`.

---

## 12) Common first-run errors

1. **`terraform output` shows no outputs**
   - Cause: you ran `plan` but not `apply`.
   - Fix: run `terraform apply` first, then `terraform output`.

2. **IAM `AccessDenied` (for `CreateRole`)**
   - Cause: deploy user lacks IAM permissions.
   - Fix: grant IAM role/instance-profile create+attach permissions.

3. **Managed policy `NoSuchEntity` for EB managed updates**
   - Cause: wrong policy ARN variant.
   - Fix: use `arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy`.

---

## 13) How this maps to your current GitHub Actions flow

Your existing deploy workflow expects an EB application/environment to exist.
This Terraform setup provides that infrastructure baseline, so your CI/CD can deploy consistently.

In short:

- Terraform manages the platform (AWS infra).
- GitHub Actions manages app delivery (build/test/deploy).
