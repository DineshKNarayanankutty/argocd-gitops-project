# Deploying the ArgoCD GitOps Project on Amazon EKS

**Follow these steps in exact order. Do not skip a verification check — each one exists because skipping it is exactly where this deployment has failed before.**

This guide assumes the project's Terraform, Kubernetes, and Helm configuration already exists in the GitHub repository. You are not writing any new code here — you are cloning it and running it.

| | |
|---|---|
| **Repository** | `https://github.com/dkn/argocd-gitops-project.git` |
| **AWS Region** | `ap-south-1` |
| **EKS Cluster Name** | `argocd-cluster` |
| **ArgoCD Namespace** | `argocd` |
| **Application Namespace** | `dkn-argocd-ns` |
| **Estimated total time** | 45–70 minutes (most of it is waiting for AWS, not typing) |

Copy every command exactly as written. Anywhere you see `<LIKE_THIS>`, replace it — including the angle brackets — with the real value, which you'll get from an earlier step's output.

---

## Before You Start: Verify Your Tools

Run each of these. Every one must print a version number with no error.

```bash
aws --version
terraform --version
kubectl version --client
helm version
git --version
```

> **If any command says "command not found"**: stop here and install that tool before continuing. Don't try to work around a missing tool — every step after this assumes all five are present.

---

## Step 1 — Configure AWS Access

```bash
aws configure
```

Enter your AWS Access Key ID, Secret Access Key, and set the default region to `ap-south-1` when prompted.

Confirm it worked:

```bash
aws sts get-caller-identity
```

**Expected result:** a JSON block with your `Account`, `UserId`, and `Arn`. If this errors out, your credentials are wrong or missing — fix that before continuing, nothing else in this guide will work otherwise.

```bash
aws configure get region
```

**Expected result:** `ap-south-1`. If it prints nothing or something else, run:

```bash
aws configure set region ap-south-1
```

> ⚠️ **Never** put AWS keys inside any file in the repository. If you ever do this by accident, rotate the key immediately — don't just delete it from the file, since it's still in your Git history.

---

## Step 2 — Clone the Repository

```bash
git clone https://github.com/dkn/argocd-gitops-project.git
cd argocd-gitops-project
```

Confirm the layout matches this before continuing:

```
argocd-gitops-project/
├── infrastructure/          ← Terraform (AWS resources)
│   ├── main.tf
│   ├── alb-controller.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── versions.tf
│   └── .gitignore
└── gitops/
    ├── k8s/                 ← the application (ArgoCD manages this, you don't)
    │   ├── namespace.yaml
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── ingress.yaml
    └── argocd/
        └── application.yaml ← the ONLY file in gitops/ you apply manually
```

Check it with:

```bash
find . -type f -name "*.tf" -o -type f -name "*.yaml"
```

> **If files are missing**: you're on the wrong branch, or the repo isn't fully pushed. Run `git branch -a` and `git status` before going any further — don't try to recreate missing files by hand.

---

## Step 3 — Provision the AWS Infrastructure

```bash
cd infrastructure
terraform init
```

**Expected result:** ends with `Terraform has been successfully initialized!`

```bash
terraform fmt -check
terraform validate
```

**Expected result:** `validate` ends with `Success! The configuration is valid.` If `fmt -check` lists files, that's just a formatting nit — not a blocker, but run `terraform fmt` to clean it up if you want.

```bash
terraform plan -out=tfplan
```

Read the output before you go further. Confirm you can see, somewhere in the plan:

- [ ] Region `ap-south-1` and cluster name `argocd-cluster`
- [ ] A VPC with 2 public and 2 private subnets, and a NAT Gateway
- [ ] An EKS cluster resource and one `aws_eks_node_group`
- [ ] Four `aws_eks_addon` resources (VPC CNI, kube-proxy, CoreDNS, Pod Identity Agent)
- [ ] An IAM role for `aws-load-balancer-controller`

> **If any of these are missing from the plan**, do not apply. Something in the repo's Terraform files doesn't match this guide's assumptions — stop and check `main.tf` and `alb-controller.tf` before proceeding.

Now apply it:

```bash
terraform apply tfplan
```

**This takes 15–20 minutes.** The EKS control plane alone is typically 10–12 minutes; the node group is another 5–8 minutes on top of that. **Do not close the terminal or press Ctrl+C while this is running.**

**Expected result:** ends with `Apply complete!` and a list of outputs.

> ⚠️ **If you see `Error: waiting for EKS Node Group ... unexpected state 'CREATE_FAILED' ... Unhealthy nodes in the kubernetes cluster`:**
> This means the cluster's networking add-ons (VPC CNI, kube-proxy, CoreDNS) aren't installed, so the worker nodes booted with no pod networking and could never register as `Ready`. Check `main.tf` for an `addons` block on the `module.eks` resource — it must exist, and `vpc-cni` must have `before_compute = true`. If it's missing, this is a bug in the repo's Terraform, not something to work around here — fix `main.tf`, then re-run `terraform apply`.

Save the outputs you'll need for later steps:

```bash
terraform output
```

Specifically, note these three values down somewhere (you'll paste them into commands in Steps 4 and 7):

```bash
terraform output -raw eks_cluster_name
terraform output -raw vpc_id
terraform output -raw load_balancer_controller_role_arn
```

---

## Step 4 — Connect kubectl to the Cluster

Still inside `infrastructure/`:

```bash
aws eks update-kubeconfig --region ap-south-1 --name argocd-cluster
```

**Expected result:** `Added new context ... to <your kubeconfig path>`

```bash
kubectl get nodes
```

**Expected result:** 2 rows, both with `STATUS` = `Ready`. If they show `NotReady`, wait 1–2 minutes and run the command again — this is normal for the first minute or two after node group creation finishes.

> **If nodes stay `NotReady` for more than 5 minutes**, run `kubectl get pods -n kube-system` and check that `aws-node-xxxxx` and `kube-proxy-xxxxx` pods exist and are `Running`. If they don't exist at all, the add-ons from Step 3 didn't actually get installed — go back and check `main.tf`.

```bash
kubectl get pods -n kube-system
```

**Expected result:** pods for `aws-node`, `kube-proxy`, and `coredns`, all `Running`.

Return to the repository root before continuing:

```bash
cd ..
```

---

## Step 5 — Install ArgoCD

```bash
kubectl create namespace argocd
```

```bash
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

**Expected result:** a long list of `created` / `configured` lines, no errors. `--server-side` is required here — ArgoCD's CRDs are too large for the default client-side apply and it will fail without this flag.

Wait for everything to come up:

```bash
kubectl get pods -n argocd -w
```

**Expected result:** every pod eventually shows `1/1` or `2/2` under `READY` and `Running` under `STATUS`. This normally takes 1–2 minutes. Press `Ctrl+C` once they're all `Running`.

You should see, at minimum: `argocd-server`, `argocd-repo-server`, `argocd-application-controller`, `argocd-redis`, `argocd-dex-server`.

Retrieve the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

**Copy this password somewhere safe** — this command only works until you change or delete the secret.

Log in from another terminal (leave this one running):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open `https://localhost:8080` in a browser. Accept the certificate warning (expected — ArgoCD's default cert is self-signed). Username `admin`, password from the previous command.

> **If `kubectl get secret argocd-initial-admin-secret` says "not found"**: ArgoCD auto-deletes this secret once the admin password has been changed once already. If this is a fresh install and it's already missing, something applied the manifests before this run — check `kubectl get pods -n argocd` to confirm ArgoCD is actually healthy, and if so, you likely already have a password set from a previous attempt.

---

## Step 6 — Deploy the Application Through ArgoCD

This is the **only** manifest you ever apply manually with `kubectl`. Everything else in `gitops/k8s/` is managed by ArgoCD from here on.

```bash
kubectl apply -f gitops/argocd/application.yaml
```

**Expected result:** `application.argoproj.io/nginx-demo created`

Watch it sync:

```bash
kubectl get applications -n argocd -w
```

**Expected result:** `SYNC STATUS` moves to `Synced` and `HEALTH STATUS` moves to `Healthy` within about a minute. Press `Ctrl+C` once you see that.

> **If it stays `OutOfSync` or `Unknown`**, run `kubectl describe application nginx-demo -n argocd` and read the `Conditions` and `Events` at the bottom — this almost always points to a Git connectivity or path problem (wrong branch, wrong path, or the repo being private without credentials configured in ArgoCD).

Confirm the application itself is actually running:

```bash
kubectl get pods -n dkn-argocd-ns
kubectl get svc -n dkn-argocd-ns
```

**Expected result:** 2 `nginx-xxxxx` pods, both `Running`, and one `nginx` service of `TYPE` = `ClusterIP`.

> **If the namespace `dkn-argocd-ns` doesn't exist at all**, check that `syncOptions` in `gitops/argocd/application.yaml` includes `CreateNamespace=true`.

---

## Step 7 — Install the AWS Load Balancer Controller

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
```

Get the two values you saved in Step 3:

```bash
terraform -chdir=infrastructure output -raw vpc_id
terraform -chdir=infrastructure output -raw load_balancer_controller_role_arn
```

Now install, substituting those two values in:

```bash
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=argocd-cluster \
  --set region=ap-south-1 \
  --set vpcId=<VPC_ID_FROM_ABOVE> \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<ROLE_ARN_FROM_ABOVE>
```

**Expected result:** ends with `STATUS: deployed`.

```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

**Expected result:** `READY` column shows `2/2`. If it shows `0/2` or `1/2`, wait 30–60 seconds and check again.

```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

**Expected result:** 2 pods, both `Running`, `0` restarts.

> ⚠️ **If the pods are stuck in `CrashLoopBackOff`:**
> ```bash
> kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
> ```
> This is almost always an IRSA mismatch — the ServiceAccount name/namespace (`kube-system:aws-load-balancer-controller`), the `role-arn` annotation, and the IAM role's trust policy all have to match exactly. Check `alb-controller.tf` for the `namespace_service_accounts` value and compare it character-for-character against what you passed to `helm install` above.

---

## Step 8 — Verify the Application Load Balancer

```bash
kubectl get ingress -n dkn-argocd-ns -w
```

**Expected result:** the `ADDRESS` column starts empty and fills in with something like `k8s-dknargoc-nginx-xxxxxxxxxx-xxxxxxxxxx.ap-south-1.elb.amazonaws.com`, usually within 1–3 minutes. Press `Ctrl+C` once it appears.

```bash
kubectl get ingress -n dkn-argocd-ns
```

Copy the `ADDRESS` value. **Wait 2–3 minutes** before testing it in a browser — the ALB needs a short window after this address first appears to finish provisioning and for DNS to propagate. Then open it in a browser.

**Expected result:** the Nginx welcome page.

> **If you get `ERR_CONNECTION_TIMED_OUT`:** check the target health of the load balancer in the EC2 console (Load Balancers → find it → Target Groups tab). Targets stuck `unhealthy` almost always mean a security group is blocking traffic — this shouldn't happen with the Terraform in this repo (it already includes a node security group rule for this), but if it does, check `eks_node_security_group_id` from `terraform output` against the EC2 console's Security Groups.
>
> **If you get `DNS_PROBE_FINISHED_NXDOMAIN`:** this is almost always just timing — re-check `kubectl get ingress -n dkn-argocd-ns` to confirm the address is still there, wait another couple of minutes, and try again. If it's been more than 5 minutes, run `kubectl describe ingress nginx -n dkn-argocd-ns` and check the `Events` section for an actual error.

---

## Step 9 — Full Verification (run this whole block)

Paste all of these together. If every line matches its "expected" note, the deployment is complete and correct.

```bash
kubectl get nodes                                    # 2 nodes, Ready
kubectl get pods -n kube-system                       # aws-node, kube-proxy, coredns: Running
kubectl get pods -n argocd                             # all Running
kubectl get applications -n argocd                      # nginx-demo: Synced, Healthy
kubectl get pods -n dkn-argocd-ns                       # 2 nginx pods, Running
kubectl get svc -n dkn-argocd-ns                        # nginx: ClusterIP
kubectl get deployment -n kube-system aws-load-balancer-controller   # READY 2/2
kubectl get ingress -n dkn-argocd-ns                     # ADDRESS is populated
```

If all eight of those match, **you're done — the deployment is fully working.** Open the ALB address in a browser one more time to see it for yourself.

---

## Optional: Prove the GitOps Loop Actually Works

Do this once, so you've personally seen ArgoCD do its job rather than just trusting it did.

**Test 1 — a Git change reaches the cluster on its own.**
Edit `gitops/k8s/deployment.yaml` in the repo, change `replicas: 2` to `replicas: 3`, then:

```bash
git add gitops/k8s/deployment.yaml
git commit -m "Scale nginx to 3 replicas"
git push
kubectl get pods -n dkn-argocd-ns -w
```

**Expected result:** a third `nginx-xxxxx` pod appears within about a minute, with no `kubectl apply` on your part.

**Test 2 — manual changes to the cluster get reverted.**

```bash
kubectl scale deployment nginx -n dkn-argocd-ns --replicas=1
kubectl get deployment nginx -n dkn-argocd-ns -w
```

**Expected result:** ArgoCD notices the drift (live = 1, Git = 3) and scales it back to 3 on its own within about a minute — this is self-healing.

---

## Cleaning Up

Do these **in this exact order**. Doing it out of order can leave an orphaned load balancer in your AWS account that keeps costing money after `terraform destroy` says it's done.

```bash
kubectl delete -f gitops/argocd/application.yaml
```

Wait ~30 seconds, then confirm the app namespace and its Ingress are gone:

```bash
kubectl get ns dkn-argocd-ns
```

**Expected result:** `Error from server (NotFound)` — that's correct, it means ArgoCD's pruning deleted everything, including the ALB.

```bash
helm uninstall aws-load-balancer-controller -n kube-system
```

Only now, destroy the AWS infrastructure:

```bash
cd infrastructure
aws sts get-caller-identity      # double check you're in the right AWS account first
terraform plan -destroy
terraform destroy
```

Type `yes` when prompted. This also takes several minutes.

Finally, check the AWS Console (EC2 → Load Balancers, EKS, VPC) for anything left over. `terraform destroy` should remove everything it created, but it's worth a 30-second look before you close the laptop.

---

## You're Done

If Step 9's checklist passed, this deployment is complete and working exactly as designed:

**Terraform** built the AWS infrastructure → **ArgoCD** deployed the application from Git → the **AWS Load Balancer Controller** exposed it through a real Application Load Balancer → and you've personally confirmed Git changes flow to the cluster automatically.

If something along the way didn't match an "expected result," the note directly under that step is the fix — this guide was written by working through every failure this exact deployment has actually produced, not by guessing what might go wrong.
