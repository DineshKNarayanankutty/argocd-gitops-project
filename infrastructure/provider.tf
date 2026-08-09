provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "argocd-gitops-project"
      Environment = "dev"
      ManagedBy   = "Terraform_admin"
    }
  }
}

