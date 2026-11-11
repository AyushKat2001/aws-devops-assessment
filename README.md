# AWS DevOps Practical Assessment (Terraform + GitHub Actions)

| # | Task | Where |
|---|------|-------|
| 1 | CI/CD: tests → Docker build → ECR → Kubernetes (EKS) | `.github/workflows/ci-cd.yml`, `app/`, `k8s/`, infra in `terraform/cicd.tf` |
| 2 | CloudFront in front of a private S3 site + cache invalidation | `terraform/cloudfront_s3.tf`, `site/` |
| 3 | Launch Template + ASG + ALB + Target Group, CPU > 70% scaling, unhealthy replacement | `terraform/asg_alb.tf`, `demos/` |

Region: `ap-south-1`. All AWS infrastructure is Terraform; the app pipeline is GitHub Actions. Plain-English explanation: [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

## Prerequisites
`terraform` (>= 1.5), `aws` CLI v2 (`aws configure`), `kubectl`, `git`, `gh` (`gh auth login`).

## Deploy

```bash
# 1. Create everything on AWS (~20 min, EKS is the slow part)
cd terraform
terraform init
terraform plan
terraform apply

# 2. Create the GitHub repo and give it the AWS role (no access keys)
cd ..
git init -b main
gh repo create ayush272001/aws-devops-assessment --public --source=. --remote=origin
gh secret set AWS_ROLE_ARN --body "$(terraform -chdir=terraform output -raw github_role_arn)"

# 3. Push -> triggers the pipeline (test, build, push to ECR, deploy to EKS)
git add . && git commit -m "AWS DevOps assessment: Terraform + CI/CD" && git push -u origin main
gh run watch
```

## Verify and demo

**Task 1 - pipeline**
```bash
aws eks update-kubeconfig --name devops-assessment --region ap-south-1
kubectl get pods,svc
curl http://$(kubectl get svc devops-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/health
aws ecr list-images --repository-name devops-assessment-app
```

**Task 2 - CloudFront**
```bash
./demos/verify-cloudfront.sh          # CloudFront 200, direct S3 403
sed -i 's/v1/v2/' site/index.html
terraform -chdir=terraform apply      # uploads new file AND invalidates the cache
curl -s $(terraform -chdir=terraform output -raw cloudfront_url)/ | grep Version   # shows v2
```

**Task 3 - ASG + ALB**
```bash
terraform -chdir=terraform output alb_url     # open it, refresh: instance ID changes
./demos/scale-out.sh                          # CPU > 70% -> ASG adds instances
./demos/unhealthy-replacement.sh              # one instance breaks -> ASG replaces it
```

## Evidence to capture
Green GitHub Actions run, ECR image tagged with the commit SHA, `kubectl get pods,svc`; CloudFront 200 vs S3 403 and the invalidation; ASG/ALB/Target Group in the console, 70% scaling policy, scaling activity history (scale-out and replacement).

## Destroy (stop charges)
```bash
aws eks update-kubeconfig --name devops-assessment --region ap-south-1
kubectl delete -f k8s/ --ignore-not-found     # removes the load balancer Kubernetes created
cd terraform && terraform destroy
```

## Design notes
- **Terraform state is local** for simplicity; a team setup would use an S3 backend with locking.
- **OIDC, not access keys:** the GitHub role can only be assumed from this repo's `main` branch.
- **Images tagged with the git SHA:** each deploy is traceable; roll back with `kubectl rollout undo`.
- **OAC + bucket policy:** S3 stays private; only this CloudFront distribution can read it.
- **ASG health check type = ELB:** an app-level failure (not just a dead VM) triggers replacement.
- **`desired_capacity` is ignored by Terraform** so it doesn't undo the autoscaler.
