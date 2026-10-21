# Streamforge AWS emulator infrastructure

Terraform mock deployment for the separate `streamforge` Jellyfin application. This repository contains infrastructure only; it does not build, modify or deploy the source repository or contain Kubernetes manifests.

The layout follows PayTrack Cloud Terraform: `environments/dev`, `environments/staging`, `environments/prod`, with reusable `modules/vpc` and `modules/streamforge`. All environments default to Ministack, using EC2 on localhost:5003 and other AWS APIs on localhost:4566. Each root has independent local state and environment-prefixed resource names.

1. Start your existing Ministack emulator.
2. Copy the chosen environment's `terraform.tfvars.example` to `terraform.tfvars` and adjust endpoints/image references.
3. Run `make validate`, `make init ENV=dev`, then `make plan ENV=dev`.
4. Review the plan, then use `terraform -chdir=environments/dev apply` to create mock resources. Repeat with staging or prod as needed.

The modeled AWS resources include a VPC, public/private subnets, NAT, ECR, ECS Fargate, an ALB, CloudWatch logs, task roles and encrypted EFS storage. Jellyfin uses one task to avoid concurrent writers; rolling replacement stops the old task first. EFS is protected from accidental Terraform destruction. The skeleton's unused banking database variables were removed: the linked application is Jellyfin, not a PostgreSQL banking backend.

This is an infrastructure mock, not a verified production deployment. Emulator API coverage may not include EFS, ALB or executing Fargate tasks. Image tags are mock defaults. An emulator plan is not proof of working streaming. The existing frontend image serves static assets; configure its Jellyfin server URL when testing actual containers. For real AWS, supply real images and configure TLS, configure persistent state and backups, assess Jellyfin database filesystem suitability, and explicitly set `use_local_emulator=false`.

The original `terraform/terraform.tfvars` is retained locally for reference and is not committed. No AWS apply is performed by CI; CI only formats and validates all three roots.
