module "load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.8"

  name = "${var.cluster_name}-alb-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      # Must match the ServiceAccount name/namespace the Helm chart creates.
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Project = "argocd-gitops-project"
  }
}

output "load_balancer_controller_role_arn" {
  description = "IAM role ARN to give the aws-load-balancer-controller Helm chart"
  value       = module.load_balancer_controller_irsa.arn
}
