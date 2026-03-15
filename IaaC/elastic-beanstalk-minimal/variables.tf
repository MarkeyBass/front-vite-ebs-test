variable "aws_region" {
  description = "AWS region for Elastic Beanstalk resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Elastic Beanstalk application name and resource prefix"
  type        = string
  default     = "frontend-vite-demo"
}

variable "environment_name" {
  description = "Elastic Beanstalk environment name"
  type        = string
  default     = "frontend-vite-demo-env"
}

variable "instance_type" {
  description = "EC2 instance type for the Beanstalk environment"
  type        = string
  default     = "t3.micro"
}

variable "tags" {
  description = "Extra tags to apply to managed resources"
  type        = map(string)
  default = {
    Owner    = "mark"
    Lifespan = "temporary"
  }
}

variable "deployment_bucket_name" {
  description = "Optional custom S3 bucket name for Elastic Beanstalk deployment artifacts. Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "deployment_bucket_force_destroy" {
  description = "If true, Terraform can delete the deployment bucket even when it contains objects."
  type        = bool
  default     = true
}
