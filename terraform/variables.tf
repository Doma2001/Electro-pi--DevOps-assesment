variable "aws_region" {
  description = "AWS region for the assessment."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Short project name used in resource naming."
  type        = string
  default     = "cloud-devops-assessment"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "assessment"
}

variable "github_repo" {
  description = "GitHub repository in owner/repository format, used to scope OIDC trust."
  type        = string
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "assessment"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "assessment_admin"
}

variable "db_instance_class" {
  description = "RDS instance class. Change only after checking your account's Free Tier eligibility."
  type        = string
  default     = "db.t3.micro"
}

variable "ecs_desired_count" {
  description = "Initial ECS service task count. Kept at zero so Terraform can create infrastructure before the first CI/CD image exists."
  type        = number
  default     = 0
}

variable "frontend_bucket_name" {
  description = "Optional exact S3 bucket name. Leave empty to generate a globally unique name."
  type        = string
  default     = ""
}
