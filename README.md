# Electro-pi--DevOps-assesment
# Cloud / DevOps Technical Assessment

A small three-tier web application demonstrating Infrastructure as Code, containerization, CI/CD, secrets management, and basic monitoring on AWS.

The application consists of a static HTML/JavaScript frontend, a FastAPI backend, and a PostgreSQL database. Terraform provisions the AWS infrastructure, Docker packages the API, and GitHub Actions tests and deploys changes pushed to `main`.

> **Assessment scope:** This repository focuses on infrastructure and automation rather than application features. Review the configuration and estimated AWS costs before deploying. The Terraform configuration includes resources that can incur charges.

## Contents

- [Architecture](#architecture)
- [Technology stack](#technology-stack)
- [Repository structure](#repository-structure)
- [Run locally](#run-locally)
- [Deploy to AWS](#deploy-to-aws)
- [CI/CD pipeline](#cicd-pipeline)
- [Security](#security)
- [Logging and monitoring](#logging-and-monitoring)
- [Key decisions and trade-offs](#key-decisions-and-trade-offs)
- [Production considerations](#production-considerations)
- [Cleanup](#cleanup)
- [Troubleshooting](#troubleshooting)

## Architecture

```mermaid
flowchart TD
    User[User's browser] -->|HTTP| Frontend[S3 static website]
    User -->|HTTP API requests| ALB[Application Load Balancer]
    Frontend -->|Calls API URL| ALB
    ALB -->|Port 8000| ECS[ECS Fargate service]
    ECS -->|Port 5432| RDS[(RDS PostgreSQL)]
    ECS --> Secrets[AWS Secrets Manager]
    ECS --> Logs[CloudWatch Logs]
    ECS --> Metrics[CloudWatch CPU alarm]
    GH[GitHub Actions] -->|OIDC role assumption| IAM[AWS IAM role]
    GH -->|Push image| ECR[Amazon ECR]
    GH -->|Update service| ECS
    GH -->|Publish static files| Frontend
```

### Request flow

1. The browser loads the static frontend from the S3 website endpoint.
2. The frontend sends API requests to the Application Load Balancer (ALB).
3. The ALB forwards requests to the FastAPI container running on Amazon ECS with AWS Fargate.
4. The API reads and writes items in the managed PostgreSQL database on Amazon RDS.
5. Database connection settings are provided to the ECS task through AWS Secrets Manager.
6. Container logs are sent to CloudWatch Logs, and a CloudWatch alarm monitors ECS service CPU utilization.

The current configuration uses HTTP endpoints for the assessment. HTTPS and a custom domain should be added before production use.

## Technology stack

| Area | Technology |
|---|---|
| Frontend | HTML, CSS, vanilla JavaScript |
| API | Python 3.12, FastAPI, Uvicorn |
| Database | PostgreSQL 16 (RDS in AWS; PostgreSQL container locally) |
| Containers | Docker, Docker Compose |
| Infrastructure as Code | Terraform |
| Compute | Amazon ECS Fargate |
| Container registry | Amazon ECR |
| Static hosting | Amazon S3 website hosting |
| CI/CD | GitHub Actions |
| Secrets | AWS Secrets Manager and GitHub OIDC |
| Monitoring/logging | Amazon CloudWatch |

## Repository structure

```text
.
├── .env.example                  # Example local environment variables (review format before use)
├── .github/
│   └── workflows/
│       └── deploy.yml            # Test, build, push, and deploy workflow
├── app/
│   ├── .dockerignore              # Excludes unnecessary files from Docker build context
│   ├── Dockerfile                 # Multi-stage API container build; runs as non-root
│   ├── main.py                    # FastAPI routes and PostgreSQL access
│   ├── requirements.txt           # Runtime Python dependencies
│   ├── requirements-dev.txt       # Test/development dependencies
│   └── test_main.py               # Basic API and CORS tests
├── frontend/
│   ├── index.html                 # Static UI
│   ├── app.js                     # Health check and item list/create requests
│   └── config.js                  # API base URL configuration
├── terraform/
│   ├── versions.tf                # Terraform/provider version constraints
│   ├── provider.tf                # AWS provider, region, default tags, data sources
│   ├── variables.tf               # Configurable input variables
│   ├── terraform.tfvars.example   # Example deployment values
│   ├── network.tf                 # VPC, public/private subnets, routes, internet gateway
│   ├── security.tf                # ALB, ECS, and database security groups
│   ├── compute.tf                 # ECR, ECS/Fargate, ALB, target group, log group
│   ├── database.tf                # RDS PostgreSQL, generated password, Secrets Manager secret
│   ├── iam.tf                     # ECS roles and GitHub Actions OIDC deployment role
│   ├── storage.tf                 # S3 frontend website and bucket policy
│   ├── monitoring.tf               # CloudWatch CPU utilization alarm
│   └── outputs.tf                 # URLs and resource identifiers
├── docker-compose.yml             # Local API and PostgreSQL stack
└── README.md
```

## Run locally

### Prerequisites

- Docker and Docker Compose v2
- Alternatively, Python 3.12 and a local PostgreSQL 16 instance

### Option 1: Docker Compose

Create a `.env` file in the repository root. The Compose file expects standard `KEY=value` environment-variable syntax; check `.env.example` and use values like these:

```dotenv
POSTGRES_DB=assessment
POSTGRES_USER=assessment
POSTGRES_PASSWORD=local-only-change-me
```

Start the application:

```bash
docker compose up --build
```

The API is available at `http://localhost:8000`.

- Health check: `http://localhost:8000/api/health`
- List items: `http://localhost:8000/api/items`
- Frontend: open `frontend/index.html` in a browser. The default API URL in `frontend/app.js` is `http://localhost:8000`.

The Compose file starts PostgreSQL and the API; it does **not** serve the frontend through a web server. If browser restrictions prevent opening the HTML file directly, serve the `frontend/` directory with a local static HTTP server, for example:

```bash
python -m http.server 8080 --directory frontend
```

Then visit `http://localhost:8080`. The frontend's default API URL is configured in `frontend/config.js`; for local use, set it to `http://localhost:8000`.

Stop the stack:

```bash
docker compose down
```

Remove the local database volume/data if one has been added to your Compose configuration and you intentionally want to reset it. Do not use destructive cleanup commands without checking which data they affect.

### Option 2: Run the API with Python

Create and activate a virtual environment, then install the dependencies:

```bash
python3.12 -m venv .venv
source .venv/bin/activate        # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r app/requirements.txt
pip install -r app/requirements-dev.txt
```

Set `DATABASE_URL` to a reachable PostgreSQL database, then start the API:

```bash
export DATABASE_URL='postgresql://assessment:local-only-change-me@localhost:5432/assessment'
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

On Windows PowerShell, use `$env:DATABASE_URL='postgresql://assessment:local-only-change-me@localhost:5432/assessment'` instead of `export`.

### Run tests

From the repository root:

```bash
pip install -r app/requirements-dev.txt
cd app
pytest -q
```

The included tests check the health endpoint and the configured CORS response. They are intentionally small to match the assessment scope.

### API endpoints

| Method | Endpoint | Purpose |
|---|---|---|
| `GET` | `/api/health` | Returns API health status |
| `GET` | `/api/items` | Lists stored items |
| `POST` | `/api/items` | Creates an item; request body: `{"name": "Example item"}` |

Example request:

```bash
curl -X POST http://localhost:8000/api/items \
  -H 'Content-Type: application/json' \
  -d '{"name":"Example item"}'
```

## Deploy to AWS

### Prerequisites

- An AWS account and credentials with permission to create the resources in this project.
- AWS CLI configured for the intended account.
- Terraform `>= 1.6.0`.
- A GitHub repository containing this project, with the default deployment branch named `main`.
- An existing GitHub Actions OIDC identity provider in AWS IAM for `https://token.actions.githubusercontent.com`. The Terraform configuration looks up this provider; it does not create it.
- Review of AWS pricing and the account's eligibility for any free-tier offers.

The example Terraform variables use `eu-central-1`. Change the region if needed and ensure all resources are supported there.

### 1. Configure Terraform

From the repository root:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`, especially `github_repo`, so it contains your GitHub repository in `OWNER/REPOSITORY` format. Review `aws_region`, `project_name`, `environment`, database settings, and the desired ECS task count.

Initialize and review the plan:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

Apply only after reviewing the planned resources and costs:

```bash
terraform apply
```

Terraform creates the VPC/subnets, ALB, ECS cluster/service and task definition, ECR repository, RDS database, S3 website bucket, IAM roles, Secrets Manager secret, CloudWatch log group, and CPU alarm.

**First deployment note:** the example sets `ecs_desired_count = 0` so the infrastructure can be created before a real container image has been published. The GitHub Actions workflow sets the ECS desired count to `1` when it deploys. The ECS task definition initially contains a placeholder image; the workflow registers a new revision with the built image.

### 2. Configure GitHub Actions

The workflow expects an Actions **repository variable** named `AWS_ROLE_ARN` containing the ARN of the IAM role created for GitHub Actions. Add it under **GitHub repository → Settings → Secrets and variables → Actions → Variables**.

The role trust policy is restricted to the configured repository and the `main` branch. Confirm that the repository identifier in `terraform.tfvars` matches the repository running the workflow, and inspect `terraform/iam.tf` for any repository-specific trust-policy entries before applying.

The workflow uses GitHub's OIDC token to assume the AWS role. It does not require long-lived AWS access keys to be stored in GitHub. Ensure the role has the permissions required by the workflow and Terraform-created resources.

### 3. Trigger deployment

Commit and push the project to `main`:

```bash
git add .
git commit -m "Configure cloud DevOps assessment"
git push origin main
```

The workflow in `.github/workflows/deploy.yml` runs tests, builds and pushes the API image, registers a new ECS task definition revision, updates the ECS service, waits for service stability, renders the frontend API URL, and syncs the frontend to S3.

After a successful run, use the Terraform outputs to find the endpoints:

```bash
cd terraform
terraform output
```

The `backend_api_url` and `frontend_website_url` outputs use HTTP in this assessment configuration.

## CI/CD pipeline

The GitHub Actions workflow runs on pushes to `main` and follows this sequence:

1. **Checkout:** obtains the repository source.
2. **Build check:** compiles Python files with `compileall`.
3. **Test:** runs `pytest`.
4. **Authenticate:** assumes the AWS deployment role using OIDC.
5. **Build and publish:** builds the backend Docker image and pushes commit-SHA and `latest` tags to ECR.
6. **Deploy backend:** registers a task definition revision, updates ECS Fargate, and waits for the service to stabilize.
7. **Publish frontend:** substitutes the ALB URL into `frontend/config.js` and syncs the static files to S3.

Image tags based on the commit SHA provide a traceable reference to the source revision. ECR image scanning on push is enabled, and a lifecycle policy retains the five most recent images.

## Security

The project implements several baseline controls:

- **Network segmentation:** the VPC has public and private subnets. The RDS instance is configured as non-public and placed in private subnets.
- **Security groups:** inbound HTTP traffic is allowed to the ALB on port 80; ECS port 8000 accepts traffic from the ALB security group; PostgreSQL port 5432 accepts traffic from the ECS security group.
- **Secrets:** Terraform generates a database password and stores database connection fields in AWS Secrets Manager. ECS injects those fields into the backend task.
- **IAM:** ECS execution/task roles are separate from the GitHub Actions deployment role. The deployment role uses OIDC rather than stored AWS access keys.
- **Encryption:** RDS storage encryption is enabled.
- **Container:** the Dockerfile uses a multi-stage build and runs the application as a non-root user.
- **Image hygiene:** `.dockerignore` excludes unnecessary build-context files.

### Security limitations to address

This is an assessment configuration, not a production security baseline:

- The ALB and S3 static website use HTTP. Add HTTPS with ACM and an appropriate delivery layer such as CloudFront before production.
- The S3 website bucket allows public object reads by design. For a production frontend, consider CloudFront with private S3 origin access instead.
- `ALLOWED_ORIGINS` is currently set to `*`. Restrict it to the actual frontend origin for deployment.
- ECS tasks are assigned public IPs in public subnets to avoid the cost and complexity of a NAT Gateway. For a production design, use private subnets and plan controlled egress.
- Review IAM policies and trust conditions against the exact repository and required actions. Avoid broad permissions where resource-scoped permissions are supported.
- Terraform state may contain sensitive values. Use a protected remote state backend with encryption, access controls, and state locking for shared or production environments. Do not commit `terraform.tfstate`, `.terraform/`, or `terraform.tfvars`.
- The RDS configuration has a short backup retention period and disables deletion protection for assessment cleanup. Change these settings for persistent environments.

## Logging and monitoring

- **Application logs:** ECS sends container logs to the CloudWatch log group `/<project_name>/backend`, with seven-day retention.
- **Container Insights:** enabled on the ECS cluster.
- **Health checks:** the API exposes `/api/health`; both the container and ALB target group use health checks.
- **Example alarm:** CloudWatch monitors average ECS service CPU utilization and enters alarm state when it exceeds 80% over a five-minute period.

The alarm is an example and does not currently configure an SNS notification target. For operational alerting, connect it to an SNS topic and a monitored notification channel.

## Key decisions and trade-offs

- **AWS:** AWS provides managed services for compute, registry, database, secrets, logging, and static hosting in one cloud environment.
- **Terraform split by concern:** network, compute, database, IAM, storage, security, monitoring, variables, and outputs are kept in separate files for readability and maintainability. They are organized by concern rather than extracted into reusable child modules.
- **ECS Fargate:** avoids managing EC2 hosts, at the cost of per-task compute charges and less host-level control.
- **RDS PostgreSQL:** uses a managed relational database instead of maintaining a database container in the cloud.
- **S3 website hosting:** is simple and low-overhead for a static demo, but the website endpoint is HTTP and public.
- **No NAT Gateway:** private database subnets do not require outbound internet access in this design. ECS runs in public subnets with public IPs to keep the assessment setup simpler and avoid NAT Gateway charges.
- **Small test suite:** the pipeline demonstrates a test stage without attempting comprehensive application coverage, consistent with the assessment.
- **Cost-aware defaults:** the database uses a small configurable instance class, log retention is seven days, ECR retains five recent images, and the ECS service initially has zero desired tasks. These settings reduce some ongoing costs but do not make the deployment cost-free.

## Production considerations

For production, run ECS tasks in private subnets behind an HTTPS-enabled ALB, serve the frontend through CloudFront with a private S3 origin, and restrict CORS to the approved frontend domain. Enable Multi-AZ RDS, longer point-in-time recovery/backup retention, deletion protection, and a tested restore process. Add autoscaling, deployment and database alarms, SNS notifications, centralized dashboards, vulnerability-management gates, and more comprehensive tests. Store Terraform state in a secured remote backend and use separate accounts or environments with reviewed IAM boundaries. Estimate costs before enabling high availability: multiple tasks, Multi-AZ database deployment, load balancing, logging, and data transfer increase the monthly spend. The assessment configuration prioritizes a clear, repeatable demonstration over full resilience and production hardening.

## Cleanup

After capturing any evidence needed for submission, remove the assessment resources to avoid ongoing charges:

```bash
cd terraform
terraform destroy
```

Review the destroy plan before confirming. Back up any evidence or data you need first. The S3 bucket is configured with `force_destroy = true`, and the RDS instance skips its final snapshot, so objects and database data may be permanently deleted. Remove the GitHub Actions repository variable if it is no longer needed.

## Troubleshooting

- **GitHub Actions cannot assume the role:** verify the OIDC provider exists, `AWS_ROLE_ARN` is set as a repository variable, and the IAM trust policy matches the exact `OWNER/REPOSITORY` and `main` branch.
- **ECS tasks fail to start:** check the ECS service events, task stopped reason, ECR image, execution-role permissions, and CloudWatch logs. Confirm that the first successful workflow run has registered a real image revision.
- **Frontend cannot reach the API:** check `frontend/config.js`, the ALB endpoint, target health, security groups, and browser console. CORS must permit the frontend's origin.
- **Database connection errors:** verify the Secrets Manager fields, RDS status, database security-group ingress from ECS, and application logs.
- **Terraform reports the GitHub OIDC provider is missing:** create the GitHub Actions OIDC provider in IAM before running Terraform, because this configuration references it as an existing provider.
- **Unexpected AWS charges:** inspect the deployed resources and run `terraform destroy` when the assessment is complete.
