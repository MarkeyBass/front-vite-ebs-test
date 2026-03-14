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
