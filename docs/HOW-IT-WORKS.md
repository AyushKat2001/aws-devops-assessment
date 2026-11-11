# How it works (like you're 5)

**The big idea:** we built a tiny toy town on AWS, and a robot that keeps it up to date.

## Terraform = the LEGO instruction sheet
We write down the picture of what we want (`.tf` files). Terraform reads it and builds the AWS LEGO for us. `terraform destroy` puts every brick back in the box.

## Task 1 - The robot baker (CI/CD)
- Your code on GitHub is a **recipe**.
- Every time you change the recipe, the **robot (GitHub Actions)** wakes up.
- It first **tastes the recipe** (runs tests). If it tastes bad, the robot stops.
- If it's good, it packs the cake in a **box** (Docker image).
- It puts the box in a **warehouse** (ECR), with the recipe's version number on it.
- Then it delivers the box to the **shop** (Kubernetes on EKS), which hands cakes to customers.
- The robot doesn't get a copy of your house key. It gets a **visitor badge that expires** (OIDC).

## Task 2 - The locked toy box with shops everywhere (S3 + CloudFront)
- **S3** is a locked toy box with your website inside. Nobody can open it directly (403).
- **CloudFront** is a chain of little toy shops around the world, each keeping a copy of the toys, so kids get them fast.
- Only the shops have the key to the toy box (OAC).
- **Invalidation** = "throw away the old copies, bring fresh ones", so everyone sees the new version.

## Task 3 - The busy ice-cream stand (ALB + ASG)
- **Launch Template** = the helper's job description and uniform, so every new helper is identical.
- **Target Group** = the list of helpers who are ready to serve.
- **ALB** = the friendly person at the front who points each customer to a free helper.
- **ASG** = the boss. If the helpers get too tired (CPU above 70%), the boss hires more. When it's quiet, helpers go home.
- **Health check** = the front person asks every few seconds "are you OK?". If a helper doesn't answer, the boss replaces them with a new one automatically.

## The whole day, in one line
You change the recipe -> robot tests, boxes, stores, delivers it -> customers get it from the shop; meanwhile the toy shops (CloudFront) and ice-cream helpers (ASG) look after themselves, and Terraform can rebuild or remove the whole town any time.
