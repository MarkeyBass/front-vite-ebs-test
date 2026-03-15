output "elastic_beanstalk_application_name" {
  description = "Elastic Beanstalk application name"
  value       = aws_elastic_beanstalk_application.this.name
}

output "elastic_beanstalk_environment_name" {
  description = "Elastic Beanstalk environment name"
  value       = aws_elastic_beanstalk_environment.this.name
}

output "elastic_beanstalk_environment_url" {
  description = "Elastic Beanstalk CNAME URL"
  value       = aws_elastic_beanstalk_environment.this.cname
}

output "solution_stack_name" {
  description = "Selected most recent Docker solution stack"
  value       = data.aws_elastic_beanstalk_solution_stack.docker.name
}

output "deployment_bucket_name" {
  description = "S3 bucket name for Elastic Beanstalk deployment artifacts"
  value       = aws_s3_bucket.deployment_artifacts.bucket
}
