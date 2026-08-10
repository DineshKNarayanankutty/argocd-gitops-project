# AWS EKS + Terraform + Argo CD + AWS Load Balancer Controller

## Repeatable GitOps Project Runbook

**Purpose:** Recreate the complete project from a fresh AWS account whenever required.

**AWS Region:** `ap-south-1`

**EKS Cluster:** `argocd-cluster`

**Argo CD Namespace:** `argocd`

**Application Namespace:** `dkn-argocd-ns`

**GitHub Repository:** `https://github.com/DineshKNarayanankutty/argocd-gitops-project.git`

---

# 1. Final Architecture

The completed project follows this architecture:

GitHub
→ Terraform
→ AWS VPC
→ EKS
→ Kubernetes

GitHub
→ Argo CD
→ Kubernetes Application

Kubernetes Ingress
→ AWS Load Balancer Controller
→ AWS Application Load Balancer
→ Nginx Pods

AWS Load Balancer Controller
→ Kubernetes ServiceAccount
→ OIDC / IRSA
→ IAM Role
→ AWS APIs

The responsibilities are intentionally separated:

* **Terraform:** AWS infrastructure
* **Helm:** Install AWS Load Balancer Controller
* **Argo CD:** GitOps application deployment
* **GitHub:** Source of truth
* **Kubernetes:** Runs the application
* **AWS ALB:** Exposes the application externally

---

# 2. Prerequisites

Before starting, confirm the following tools are installed:

* AWS CLI
* Terraform
* kubectl
* Helm
* Git
* Docker
* GitHub account
* AWS account

Verify:

`aws --version`

`terraform --version`

`kubectl version --client`

`helm version`

`git --version`

`docker --version`

---

# 3. Configure AWS CLI

Configure your AWS credentials using your normal AWS authentication method.

Verify the identity:

`aws sts get-caller-identity`

Verify the region:

`aws configure get region`

Set the region if necessary:

`aws configure set region ap-south-1`

Verify again:

`aws configure get region`

Expected region:

`ap-south-1`

Do not put AWS access keys or secrets inside Terraform files or GitHub.

---

# 4. Create the GitHub Repository

Create one GitHub repository for the complete project.

Recommended repository:

`argocd-gitops-project`

The repository should contain two logical sections:

`infrastructure/`

and

`gitops/`

Final structure:

`argocd-gitops-project/`

→ `infrastructure/`

→ `gitops/`

The infrastructure section contains Terraform.

The GitOps section contains Kubernetes and Argo CD manifests.

For this learning project, one repository is sufficient.

---

# 5. Create the Local Project Directory

Create the project directory:

`mkdir argocd-gitops-project`

`cd argocd-gitops-project`

Create the infrastructure directory:

`mkdir infrastructure`

Move into it:

`cd infrastructure`

The infrastructure directory should contain:

* Terraform version/provider configuration
* AWS provider configuration
* variables
* outputs
* main infrastructure configuration
* EKS configuration
* ALB controller IAM configuration
* Terraform variable values
* Terraform Git ignore configuration

---

# 6. Terraform Infrastructure

The Terraform layer creates the AWS infrastructure required by the project.

The final infrastructure should include:

* VPC
* Internet Gateway
* Public subnets
* Private subnets
* Route tables
* NAT Gateway
* Elastic IP
* EKS cluster
* EKS managed node group
* EKS IAM roles
* EKS security groups
* EKS KMS encryption
* EKS managed add-ons
* OIDC provider
* IAM role for AWS Load Balancer Controller

---

# 7. VPC Design

Use:

**VPC CIDR**

`10.0.0.0/16`

Use two Availability Zones:

* `ap-south-1a`
* `ap-south-1b`

Use two public subnets:

* `10.0.101.0/24`
* `10.0.102.0/24`

Use two private subnets:

* `10.0.1.0/24`
* `10.0.2.0/24`

Architecture:

VPC `10.0.0.0/16`

→ AZ `ap-south-1a`

→ Public subnet `10.0.101.0/24`

→ Private subnet `10.0.1.0/24`

→ AZ `ap-south-1b`

→ Public subnet `10.0.102.0/24`

→ Private subnet `10.0.2.0/24`

EKS worker nodes run in the private subnets.

---

# 8. NAT Gateway

Use one NAT Gateway for this learning project.

Purpose:

Private EKS nodes need outbound internet access for operations such as pulling container images.

Traffic path:

Private subnet

→ NAT Gateway

→ Internet Gateway

→ Internet

One NAT Gateway keeps the project cheaper.

For a production multi-AZ architecture, separate NAT Gateways per AZ may be preferred.

---

# 9. EKS Configuration

Use:

**Cluster name**

`argocd-cluster`

**Kubernetes version**

`1.35`

**Region**

`ap-south-1`

Use managed node groups.

Node group:

`argocd_nodes`

Instance type:

`t3.medium`

Desired nodes:

`2`

Minimum:

`1`

Maximum:

`2`

Worker nodes should use:

`AL2023_x86_64_STANDARD`

Worker nodes should be deployed into the private subnets.

---

# 10. EKS API Access

Enable both:

* Private endpoint access
* Public endpoint access

For public access, restrict the allowed CIDR to your own public IP.

Find your current public IP:

`(Invoke-RestMethod https://checkip.amazonaws.com).Trim()`

Use your public IP with `/32`.

Example concept:

`YOUR_PUBLIC_IP/32`

Do not use `0.0.0.0/0` for the EKS API unless you intentionally need unrestricted public API access.

Important: if your home/office public IP changes, update the Terraform configuration before attempting to access the EKS API.

---

# 11. EKS Managed Add-ons

The EKS configuration must explicitly manage these add-ons:

* VPC CNI
* kube-proxy
* CoreDNS
* EKS Pod Identity Agent

The VPC CNI should be configured to be installed before compute/node creation.

This ensures the cluster networking components are available as the worker nodes are brought online.

The EKS cluster should not be considered ready until:

`kubectl get nodes`

shows all expected nodes as:

`Ready`

---

# 12. EKS Encryption

Enable EKS secrets encryption using KMS.

The project should create a KMS key for EKS secrets.

Enable key rotation.

This gives the project an additional security feature suitable for demonstrating production-oriented EKS infrastructure.

---

# 13. Initialize Terraform

From the infrastructure directory:

`terraform init`

If you have modified modules or providers and need to refresh them:

`terraform init -upgrade`

Then format:

`terraform fmt`

Validate:

`terraform validate`

---

# 14. Review Terraform Plan

Run:

`terraform plan`

Before applying, verify that:

* The correct AWS region is shown.
* The correct EKS cluster name is shown.
* The correct Kubernetes version is shown.
* Two Availability Zones are used.
* Private and public subnets are created.
* NAT Gateway is present.
* EKS managed node group is present.
* AL2023 worker nodes are selected.
* EKS add-ons are present.
* KMS encryption is present.
* OIDC is enabled.
* ALB controller IAM resources are present.

Only continue when the plan looks correct.

---

# 15. Apply Terraform

Run:

`terraform apply`

Review the plan.

Confirm with:

`yes`

Wait until Terraform completes.

Do not interrupt the operation while the EKS control plane or managed node group is being created.

---

# 16. Verify Terraform Outputs

After successful completion:

`terraform output`

At minimum, record:

* EKS cluster name
* EKS endpoint
* VPC ID
* private subnet IDs
* public subnet IDs
* AWS Load Balancer Controller IAM role ARN

You will need the VPC ID and Load Balancer Controller role ARN during the next stages.

---

# 17. Configure kubectl

Connect your local kubectl configuration to EKS:

`aws eks update-kubeconfig --region ap-south-1 --name argocd-cluster`

Verify:

`kubectl get nodes`

Expected result:

Two worker nodes should be `Ready`.

Then:

`kubectl get pods -A`

Check that the Kubernetes system components are running.

---

# 18. Verify EKS Add-ons

Check:

`aws eks list-addons --cluster-name argocd-cluster --region ap-south-1`

Verify the expected add-ons are present.

Then:

`kubectl get pods -n kube-system`

Confirm the important networking components are healthy.

The EKS layer is considered complete when:

* Cluster is ACTIVE
* Nodes are Ready
* CoreDNS is Running
* VPC CNI is Running
* kube-proxy is Running

---

# 19. Install Argo CD

Use the conventional Argo CD namespace:

`argocd`

Create it:

`kubectl create namespace argocd`

Install the official Argo CD stable manifest using server-side apply:

`kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml`

The official documentation recommends the `argocd` namespace, and current documentation recommends server-side apply because of CRD size limitations.

For a completely reproducible environment, record the Argo CD version used. For example, the Argo CD releases page currently shows v3.4.2 as the latest release; a pinned release URL can be used instead of the moving `stable` URL when exact reproducibility is required.

---

# 20. Verify Argo CD

Run:

`kubectl get pods -n argocd`

Wait until the Argo CD components are Running.

Then verify:

`kubectl get svc -n argocd`

Important components include:

* argocd-server
* argocd-repo-server
* argocd-application-controller
* argocd-redis
* argocd-dex-server

---

# 21. Verify Argo CD RBAC

Because we are using the standard `argocd` namespace, the standard Argo CD installation's ClusterRoleBindings will match the ServiceAccounts.

Verify:

`kubectl auth can-i list namespaces --as=system:serviceaccount:argocd:argocd-application-controller`

Expected:

`yes`

This is an important verification step.

---

# 22. Access the Argo CD UI

Use port forwarding rather than exposing the Argo CD server publicly for this simple project.

Run:

`kubectl port-forward svc/argocd-server -n argocd 8080:443`

Keep this terminal open.

Open:

`https://localhost:8080`

A browser certificate warning is expected because the initial Argo CD installation uses a self-signed certificate.

---

# 23. Retrieve the Initial Argo CD Password

The initial admin password is stored in the Kubernetes Secret:

`argocd-initial-admin-secret`

Retrieve it using kubectl.

Username:

`admin`

Use the retrieved password to log in.

After logging in successfully, remove or rotate the initial credential as appropriate for a longer-lived environment.

---

# 24. Prepare the GitOps Directory

Return to the project root.

Create:

`gitops`

Inside it create:

`gitops/k8s`

and:

`gitops/argocd`

The final structure is:

`gitops/`

→ `k8s/`

→ namespace manifest

→ deployment manifest

→ service manifest

→ ingress manifest

→ `argocd/`

→ application manifest

---

# 25. Kubernetes Application Namespace

Use:

`dkn-argocd-ns`

This namespace is separate from the Argo CD control-plane namespace.

Argo CD:

`argocd`

Application:

`dkn-argocd-ns`

This separation should be maintained.

---

# 26. Kubernetes Application

Deploy a simple Nginx application.

The Deployment should specify:

* Application name: nginx
* Namespace: dkn-argocd-ns
* Desired replicas: 2
* Container image: nginx
* Container port: 80

The application manifest should be stored in:

`gitops/k8s/`

Do not manually apply the Deployment or Service using kubectl.

Argo CD should deploy them.

---

# 27. Kubernetes Service

Use:

`ClusterIP`

Do not expose Nginx directly through a Kubernetes `LoadBalancer` Service.

The final traffic architecture should be:

Internet

→ ALB

→ Nginx Pod IP

The ClusterIP Service remains internal to Kubernetes.

---

# 28. Create the Argo CD Application

The Argo CD Application should:

* Live in namespace `argocd`
* Point to the GitHub repository
* Use the `main` branch
* Use the `gitops/k8s` directory
* Deploy to `dkn-argocd-ns`
* Use the in-cluster Kubernetes API
* Enable automated synchronization
* Enable self-healing
* Enable pruning
* Allow namespace creation

The GitHub repository is the desired state.

Argo CD continuously compares Git with the Kubernetes cluster and reconciles differences. This is the core GitOps model.

---

# 29. Push GitOps Configuration

From the project root:

`git status`

Add the GitOps files:

`git add gitops/`

Commit:

`git commit -m "Add ArgoCD GitOps application"`

Push:

`git push`

---

# 30. Create the Argo CD Application

Apply only the Argo CD Application resource:

`kubectl apply -f gitops/argocd/application.yaml`

Do not manually apply:

* namespace
* deployment
* service
* ingress

Argo CD should create those resources.

---

# 31. Verify Argo CD Synchronization

Run:

`kubectl get applications -n argocd`

Expected:

`nginx-demo`

Status should eventually become:

`Synced`

Health should become:

`Healthy`

---

# 32. Verify the Application

Run:

`kubectl get all -n dkn-argocd-ns`

Verify:

* Deployment exists
* Pods exist
* Pods are Running
* Service exists

Check pods:

`kubectl get pods -n dkn-argocd-ns`

Check deployment:

`kubectl get deployment -n dkn-argocd-ns`

---

# 33. Terraform IAM for AWS Load Balancer Controller

The AWS Load Balancer Controller needs permission to call AWS APIs.

Create the controller IAM role through Terraform.

The IAM role should:

* Use the EKS OIDC provider
* Use IRSA
* Attach the AWS Load Balancer Controller IAM policy
* Trust exactly the Kubernetes ServiceAccount:
  `kube-system:aws-load-balancer-controller`

The Terraform module used in this project is the AWS IAM module's service-account role functionality.

Run from the infrastructure directory:

`terraform init -upgrade`

Then:

`terraform fmt`

Then:

`terraform validate`

Then:

`terraform plan`

Review the plan.

Apply:

`terraform apply`

Record:

`terraform output load_balancer_controller_role_arn`

Also record:

`terraform output vpc_id`

AWS's current documentation confirms that the controller can use IRSA and that its OIDC trust is specific to the EKS cluster.

---

# 34. Install AWS Load Balancer Controller with Helm

Add the AWS EKS Helm repository:

`helm repo add eks https://aws.github.io/eks-charts`

Update it:

`helm repo update eks`

Install the controller into:

`kube-system`

Use:

* Cluster name: `argocd-cluster`
* Region: `ap-south-1`
* VPC ID: value from Terraform
* ServiceAccount: `aws-load-balancer-controller`
* IAM role ARN: value from Terraform
* ServiceAccount IAM annotation enabled

For repeatability, pin the Helm chart version used by the project rather than relying on whatever version happens to be latest. AWS's current documentation identifies controller release v2.14.1 and Helm chart 1.14.0.

---

# 35. Verify AWS Load Balancer Controller

Run:

`kubectl get deployment -n kube-system aws-load-balancer-controller`

Expected:

`READY 2/2`

Then:

`kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`

Both controller Pods should be Running.

Check the ServiceAccount:

`kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml`

Verify that it contains the IAM role annotation.

---

# 36. Create the Kubernetes Ingress

The application Ingress should:

* Live in `dkn-argocd-ns`
* Use the ALB ingress class
* Use an internet-facing ALB
* Use IP target mode
* Listen on HTTP port 80
* Forward traffic to the Nginx Service on port 80

The important architecture is:

Internet

→ AWS ALB

→ Pod IP

→ Nginx

IP target mode means the ALB sends traffic directly to Pod IPs rather than requiring NodePort routing.

The AWS Load Balancer Controller watches Kubernetes Ingress resources and provisions AWS load balancers accordingly.

---

# 37. Push the Ingress Through Git

Add the Ingress manifest to:

`gitops/k8s/`

Commit:

`git add gitops/k8s/`

`git commit -m "Add ALB ingress"`

Push:

`git push`

Do not manually apply the Ingress.

Argo CD should detect the Git change and synchronize it.

---

# 38. Verify the Ingress

Run:

`kubectl get ingress -n dkn-argocd-ns`

Initially, the ADDRESS field may be empty.

Watch it:

`kubectl get ingress -n dkn-argocd-ns -w`

Wait until the AWS ALB DNS name appears.

AWS documents that the controller provisions AWS load balancers from Kubernetes Ingress/Service resources.

---

# 39. Test the Application

Once the ALB DNS name appears, retrieve it:

`kubectl get ingress -n dkn-argocd-ns`

Copy the ALB hostname.

Open it in a browser.

Expected result:

Nginx welcome page.

At this point the complete path is working:

Internet

→ AWS ALB

→ AWS Load Balancer Controller

→ Nginx Service

→ Nginx Pods

---

# 40. Verify the Complete GitOps State

Run:

`kubectl get applications -n argocd`

Expected:

`nginx-demo`

`Synced`

`Healthy`

Then:

`kubectl get pods -n dkn-argocd-ns`

All application Pods should be Running.

Then:

`kubectl get ingress -n dkn-argocd-ns`

The ALB address should be present.

---

# 41. GitOps Test 1 — Scale Through Git

Change the Nginx desired replica count in the GitHub Deployment manifest.

For example, change:

2 replicas

to:

3 replicas

Commit:

`git add gitops/k8s/`

`git commit -m "Scale nginx to three replicas"`

`git push`

Watch:

`kubectl get pods -n dkn-argocd-ns -w`

Argo CD should detect the Git change and create the third Pod.

Verify:

`kubectl get deployment nginx -n dkn-argocd-ns`

The deployment should show:

`3/3`

This proves:

GitHub

→ Argo CD

→ Kubernetes

---

# 42. GitOps Test 2 — Self-Healing

Make sure Git says:

3 replicas.

Then intentionally change the live Kubernetes state:

Scale the Deployment manually to 1 replica.

Watch:

`kubectl get deployment nginx -n dkn-argocd-ns -w`

Because Argo CD has self-healing enabled, it should detect that:

Git desired state = 3

Kubernetes actual state = 1

Argo CD should reconcile the cluster back to:

3 replicas

This demonstrates Argo CD's self-healing capability.

---

# 43. GitOps Test 3 — Pruning

Create a test Kubernetes resource through Git.

Push it.

Confirm Argo CD creates it.

Then remove the resource from Git.

Push again.

Because pruning is enabled, Argo CD should remove the corresponding Kubernetes resource.

This demonstrates:

Git desired state

→ Argo CD

→ Cluster reconciliation

including resource deletion.

---

# 44. Final Verification Checklist

The project is complete when all of the following are true.

## AWS

* AWS credentials work
* Region is `ap-south-1`
* VPC exists
* Two AZs exist
* Public subnets exist
* Private subnets exist
* NAT Gateway exists
* EKS cluster is ACTIVE
* EKS nodes are Ready
* KMS encryption exists
* OIDC provider exists
* ALB Controller IAM role exists

## Kubernetes

* EKS nodes are Ready
* CoreDNS is Running
* VPC CNI is Running
* kube-proxy is Running
* Argo CD is Running
* AWS Load Balancer Controller is Running
* `dkn-argocd-ns` exists
* Nginx Pods are Running
* Nginx Service is ClusterIP
* Ingress exists
* ALB address exists

## Argo CD

* Application exists
* Application is Synced
* Application is Healthy
* Automated sync is enabled
* Self-healing is enabled
* Pruning is enabled

## GitHub

* Terraform code is pushed
* Kubernetes manifests are pushed
* Argo CD Application manifest is pushed
* Ingress manifest is pushed
* No AWS credentials/secrets are committed

## Application

* ALB hostname responds
* Nginx page loads
* Git replica change is automatically deployed
* Manual Kubernetes drift is automatically corrected

---

# 45. Final Project Structure

The repository should ultimately look like:

argocd-gitops-project/

→ infrastructure/

→ Terraform configuration

→ EKS configuration

→ ALB Controller IAM configuration

→ variables

→ outputs

→ GitOps/

→ k8s/

→ namespace

→ deployment

→ service

→ ingress

→ argocd/

→ application

---

# 46. Repeatable Execution Order

Whenever you rebuild this project, follow this exact order.

## Phase 1 — AWS

1. Configure AWS CLI.
2. Verify AWS identity.
3. Set `ap-south-1`.
4. Clone/create GitHub repository.
5. Enter `infrastructure`.
6. Run Terraform initialization.
7. Format Terraform.
8. Validate Terraform.
9. Review Terraform plan.
10. Apply Terraform.
11. Verify Terraform outputs.

## Phase 2 — EKS

12. Update kubeconfig.
13. Verify EKS nodes.
14. Verify EKS system Pods.
15. Verify EKS add-ons.

## Phase 3 — Argo CD

16. Create namespace `argocd`.
17. Install Argo CD.
18. Wait for all Argo CD Pods.
19. Verify controller RBAC.
20. Access Argo CD.
21. Retrieve initial admin password.

## Phase 4 — GitOps

22. Prepare `gitops/k8s`.
23. Prepare `gitops/argocd`.
24. Push Kubernetes manifests.
25. Create Argo CD Application.
26. Verify `Synced`.
27. Verify `Healthy`.
28. Verify Nginx Pods.

## Phase 5 — AWS Load Balancer Controller

29. Add the IAM role through Terraform.
30. Apply Terraform.
31. Retrieve IAM role ARN.
32. Retrieve VPC ID.
33. Add AWS Helm repository.
34. Update Helm repository.
35. Install AWS Load Balancer Controller.
36. Verify controller Pods.
37. Verify ServiceAccount IAM annotation.

## Phase 6 — ALB

38. Change Nginx Service to ClusterIP.
39. Add Ingress.
40. Push changes to Git.
41. Wait for Argo CD synchronization.
42. Verify Ingress.
43. Wait for ALB hostname.
44. Open ALB URL.
45. Verify Nginx.

## Phase 7 — GitOps Validation

46. Change replicas in Git.
47. Push.
48. Verify Argo CD sync.
49. Verify new Pods.
50. Manually create drift.
51. Verify Argo CD self-healing.
52. Test pruning.

---

# 47. Important Rules for Repeating the Project

1. Always use `argocd` for the Argo CD namespace.

2. Always use a separate namespace for the application:
   `dkn-argocd-ns`

3. Do not manually deploy application manifests with `kubectl apply`.

4. Only the Argo CD Application itself may be initially created with kubectl.

5. Keep AWS infrastructure in Terraform.

6. Keep Kubernetes application configuration in Git.

7. Keep the AWS Load Balancer Controller IAM role in Terraform.

8. Install the AWS Load Balancer Controller with Helm.

9. Use IRSA rather than static AWS credentials.

10. Use private subnets for EKS worker nodes.

11. Restrict EKS public API access to your own public IP.

12. Do not expose the application using a bare `LoadBalancer` Service when using the ALB Ingress architecture.

13. Use ClusterIP for the Nginx Service.

14. Use Ingress for the public HTTP entry point.

15. Use ALB IP target mode.

16. Never commit AWS credentials, secrets, private keys, or tokens.

17. Run `terraform plan` before every Terraform apply.

18. Run `git diff` and `git status` before pushing changes.

19. Verify Argo CD reports `Synced` and `Healthy` after Git changes.

20. Destroy the AWS infrastructure when the lab is no longer needed to avoid unnecessary charges.

---

# 48. Cleanup After the Lab

When you are completely finished and no longer need the project:

First verify you are working in the correct AWS account:

`aws sts get-caller-identity`

Then go to:

`infrastructure`

Run:

`terraform plan`

Review what will be destroyed.

Then:

`terraform destroy`

Confirm with:

`yes`

After destruction, verify that the EKS cluster, EC2 instances, NAT Gateway, load balancers, and associated infrastructure have been removed.

Also check the AWS Console for any remaining billable resources.

Keep the GitHub repository. It contains the reusable project configuration and can be used to recreate the environment later.

---

# 49. What This Project Demonstrates

This single project demonstrates:

* AWS
* VPC
* Subnets
* NAT Gateway
* EKS
* Kubernetes
* Terraform
* Terraform modules
* EKS managed node groups
* EKS add-ons
* KMS
* IAM
* OIDC
* IRSA
* Helm
* AWS Load Balancer Controller
* ALB
* Kubernetes Ingress
* Kubernetes Services
* Git
* GitHub
* Argo CD
* GitOps
* Automated synchronization
* Self-healing
* Pruning
* Infrastructure as Code
* Kubernetes reconciliation

The strongest interview-level summary is:

"I provisioned an EKS-based Kubernetes environment on AWS using Terraform, including VPC networking, private worker nodes, KMS encryption, EKS add-ons, and IAM/OIDC integration. I installed Argo CD for GitOps-based application delivery, with GitHub acting as the source of truth. I then integrated the AWS Load Balancer Controller using IRSA and exposed the application through an AWS Application Load Balancer using Kubernetes Ingress. I validated automated synchronization, self-healing, and pruning by introducing controlled changes through Git and directly in the cluster."

---

# 50. One-Page Rebuild Sequence

For quick reference:

AWS CLI configured

↓

Verify AWS identity

↓

Set `ap-south-1`

↓

Clone GitHub repository

↓

Enter `infrastructure`

↓

Terraform init

↓

Terraform fmt

↓

Terraform validate

↓

Terraform plan

↓

Terraform apply

↓

Update kubeconfig

↓

Verify EKS nodes

↓

Verify EKS add-ons

↓

Create `argocd` namespace

↓

Install Argo CD

↓

Verify Argo CD Pods

↓

Verify Argo CD RBAC

↓

Access Argo CD

↓

Push Kubernetes manifests to GitHub

↓

Create Argo CD Application

↓

Verify `Synced + Healthy`

↓

Terraform creates ALB Controller IAM role

↓

Terraform apply

↓

Get VPC ID

↓

Get ALB Controller role ARN

↓

Add AWS EKS Helm repository

↓

Install AWS Load Balancer Controller

↓

Verify controller

↓

Service = ClusterIP

↓

Add Ingress

↓

Push to GitHub

↓

Argo CD syncs

↓

AWS ALB is created

↓

Open ALB DNS

↓

Nginx works

↓

Test Git-based scaling

↓

Test Argo CD self-healing

↓

Test pruning

↓

Project complete

---

## Official references

Argo CD's current documentation confirms the standard `argocd` namespace and the server-side installation approach.

[Argo CD documentation](https://argo-cd.readthedocs.io/en/stable/)

AWS's current documentation recommends Helm for installing the AWS Load Balancer Controller on EKS and documents IRSA/OIDC requirements.

[AWS Load Balancer Controller documentation](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)

The current Argo CD releases page can be used when you want to pin an exact Argo CD version for reproducible rebuilds.

[Argo CD releases](https://github.com/argoproj/argo-cd/releases)
