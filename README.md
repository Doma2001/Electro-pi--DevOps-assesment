# Electro-pi Containerized Application Deployment on AWS

## 1. Project Overview

This project demonstrates how to deploy a containerized application on AWS using Infrastructure as Code (IaC), container orchestration, and CI/CD automation.

To design the deployment architecture, I researched AWS best practices for deploying containerized applications and referred to the following AWS article:

**Reference:** [Fast Forward on Your First Serverless Container Deployment on AWS](https://aws.amazon.com/blogs/containers/fast-forward-on-your-first-serverless-container-deployment-on-aws/)

Based on these recommendations, I designed an architecture with some modifications to meet the requirements of this assessment.

## 2. Architecture

### 2.1 Proposed Architecture

The following diagram illustrates the proposed architecture, inspired by AWS best practices, with modifications specific to this project.

<!-- IMAGE PLACEHOLDER 1: Proposed Architecture -->

### 2.2 Full Cloud Architecture

The following diagram presents the full architecture implemented for the cloud deployment, including the AWS services and deployment workflow.

<!-- IMAGE PLACEHOLDER 2: Full Cloud Architecture -->

> **Note:** Replace the image filenames above with the actual filenames of your diagrams. Keep the images in the repository root or update the paths accordingly.

## 3. Technology Stack

| Area                       | Technology                                                     |
| -------------------------- | -------------------------------------------------------------- |
| Frontend                   | HTML, CSS, Vanilla JavaScript                                  |
| API                        | Python 3.12, FastAPI, Uvicorn                                  |
| Database                   | PostgreSQL 16, Amazon RDS in AWS, PostgreSQL container locally |
| Containers                 | Docker, Docker Compose                                         |
| Infrastructure as Code     | Terraform                                                      |
| Compute                    | Amazon ECS with AWS Fargate                                    |
| Container Registry         | Amazon Elastic Container Registry (ECR)                        |
| Static Hosting             | Amazon S3 website hosting                                      |
| CI/CD                      | GitHub Actions                                                 |
| Secrets and Authentication | AWS Secrets Manager, GitHub OIDC                               |
| Monitoring and Logging     | Amazon CloudWatch                                              |

## 4. Running the Application Locally

Before exploring the cloud architecture, you can run the application locally using Docker Desktop.

### Prerequisites

* Docker Desktop with Docker Compose.
* Python 3 installed.
* Git.

### Step 1 — Configure the Frontend

Open `frontend/config.js` and change the API base URL from:

```javascript
API_BASE_URL: "__API_BASE_URL__"
```

to:

```javascript
API_BASE_URL: "http://localhost:8000"
```

This configures the frontend to communicate with the locally running backend.

### Step 2 — Build and Start the Containers

From the project root directory, run:

```bash
docker compose up -d --build
```

This command builds the required images and starts the database and backend containers defined in the Docker Compose configuration.

### Step 3 — Verify Container Health

Run:

```bash
docker compose ps -a
```

Verify that all required containers are running and healthy. If a container is not healthy, inspect its logs:

```bash
docker compose logs
```

### Step 4 — Start the Frontend

From the project root, run:

```bash
cd frontend
python3 -m http.server 3000
```

Open the frontend in your browser:

**http://localhost:3000**

The frontend should now communicate with the backend at `http://localhost:8000`.

> **Note:** Keep the terminal running while serving the frontend. If the application uses environment-specific configuration, remember to restore or update `frontend/config.js` appropriately before deploying to AWS.

## 5. Deploying the Application to AWS

The following steps describe how to provision the AWS infrastructure and deploy the application using Terraform and GitHub Actions.

> **Important — HTTP vs. HTTPS:** This assessment uses HTTP for the public frontend and application endpoints where configured. HTTPS was not implemented because a custom domain and TLS certificate were outside the scope of this assessment. For production deployments, configure HTTPS using AWS Certificate Manager (ACM) and an appropriate domain name.

### Prerequisites

Before starting, ensure you have:

* An AWS account with the required permissions.
* AWS CLI installed and configured.
* Terraform installed.
* Git installed.
* A GitHub repository containing the project.
* Docker installed for local development and testing.

### Step 1 — Clone the Repository

Clone the project and navigate to its root directory:

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```

Replace the placeholders with your GitHub username and repository name.

### Step 2 — Configure Terraform Variables

Navigate to the Terraform directory:

```bash
cd terraform
```

Create your local Terraform variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and configure the required values. At minimum, set:

```hcl
aws_region  = "eu-central-1"
github_repo = "<your-github-username>/<your-repo-name>"
```

Make sure the repository value matches your actual GitHub repository.

> **Security note:** Do not commit `terraform.tfvars` if it contains sensitive values. Keep credentials and application secrets out of source control.

### Step 3 — Provision the AWS Infrastructure

Initialize Terraform:

```bash
terraform init
```

Review and apply the infrastructure configuration:

```bash
terraform apply
```

Review the proposed changes and confirm the operation when prompted.

After provisioning completes, retrieve the outputs needed for the next steps:

```bash
terraform output github_actions_role_arn
terraform output frontend_website_url
```

Record the role ARN and frontend URL.

### Step 4 — Configure GitHub Actions Authentication

Register the IAM role ARN as a GitHub Actions repository variable.

1. Copy the output of:

   ```bash
   terraform output github_actions_role_arn
   ```

2. Open your GitHub repository.

3. Navigate to **Settings → Secrets and variables → Actions → Variables**.

4. Click **New repository variable**.

5. Set the variable name to:

   ```text
   AWS_ROLE_ARN
   ```

6. Paste the IAM role ARN as the value.

7. Save the variable.

This allows GitHub Actions to assume the configured AWS IAM role using OpenID Connect (OIDC), provided the IAM trust policy and workflow permissions are configured correctly.

### Step 5 — Trigger the First Deployment

Return to the repository root:

```bash
cd ..
```

Trigger the GitHub Actions workflow by pushing a commit to the `main` branch.

If there are no pending changes to commit, you can create an empty commit:

```bash
git commit --allow-empty -m "Trigger first deployment"
git push origin main
```

Monitor the workflow under the **Actions** tab in your GitHub repository.

Wait for the deployment workflow to complete successfully.

### Step 6 — Verify the Deployment

Navigate to the Terraform directory:

```bash
cd terraform
```

Retrieve the frontend URL:

```bash
terraform output frontend_website_url
```

Open the URL in your browser and verify that the frontend loads correctly and can communicate with the backend API.

**Verification checklist:**

* [x] The GitHub Actions workflow completed successfully.
* [x] The frontend website is accessible.
* [x] The backend API is reachable through the configured endpoint.
* [x] The application can communicate with the database.
* [x] Application and infrastructure logs are available in CloudWatch.

Check that the endpoint uses the expected protocol. This assessment is configured for HTTP rather than HTTPS.

### Step 7 — Tear Down the Infrastructure

To remove the AWS resources created by Terraform, run:

```bash
cd terraform
terraform destroy
```

Review the proposed deletions and confirm when prompted.

> **Warning:** Destroying the infrastructure can permanently remove resources and associated data. Back up any data you need before proceeding.

## 6. Important Deployment Notes

### ECS Desired Count and GitHub Actions

The current Terraform configuration sets the ECS service's desired task count to `0`. Consequently, running `terraform apply` can return the service to zero desired tasks if that value is defined in the Terraform configuration.

After applying infrastructure changes, trigger the GitHub Actions deployment workflow to deploy or restore the application, according to the workflow's implementation.

**Important:** Verify the workflow behavior before relying on this process. A Terraform apply does not inherently trigger GitHub Actions, and a GitHub Actions run will only restore the service if the workflow explicitly deploys the task or updates the desired count.

## 7. Architecture Explanation

### Why AWS Fargate?

Since the application requires containerized workloads rather than direct management of individual EC2 instances, I selected Amazon ECS with AWS Fargate.

Fargate is a serverless compute engine for containers. It removes the need to provision and manage the underlying container-hosting EC2 instances.

The application uses an ECS cluster and service to manage its containerized workloads, with Fargate as the compute launch type.

### Why a Load Balancer?

An Application Load Balancer (ALB) provides an entry point for incoming API requests and routes them to the backend targets registered with it.

The ALB is configured across two public subnets, providing a multi-Availability Zone entry point. This configuration alone does not guarantee application high availability; the number and placement of healthy backend tasks and the database configuration also matter.

### Why Terraform?

Terraform provisions and manages the AWS infrastructure through code. This makes the deployment repeatable, allows infrastructure changes to be reviewed, and reduces the need for manual resource creation.

### Why GitHub Actions?

GitHub Actions automates the deployment workflow when changes are pushed to the configured branch.

Combined with GitHub OIDC and AWS IAM, it allows the workflow to obtain AWS credentials through role assumption rather than relying on long-lived AWS access keys stored in GitHub.

### Monitoring and Alerting

Amazon CloudWatch is used for logging and monitoring.

Due to time constraints, I did not implement the final alert-notification stage. Given more time, I would integrate Amazon Simple Notification Service (SNS) with CloudWatch alarms to send email notifications when predefined thresholds or failure conditions are reached.

## 8. Potential Improvements for Production

The current architecture is designed for an assessment, with an emphasis on demonstrating containerization, infrastructure automation, and CI/CD. A production environment would require additional measures to improve scalability, cost efficiency, security, and availability.

### 8.1 Scalability

The current setup uses a small Fargate service and a single RDS database instance.

For a production deployment, I would consider the following improvements:

* **ECS service auto scaling:** Run at least two tasks and scale the service according to CPU utilization, memory utilization, or request volume.
* **Database read scaling:** Evaluate Amazon Aurora PostgreSQL and read replicas where workload characteristics justify them.
* **CloudFront:** Distribute frontend content through CloudFront to reduce latency and improve content delivery. Depending on the routing design, CloudFront could also provide a distribution layer for API traffic.
* **Load testing:** Establish performance baselines and use representative workloads to determine scaling thresholds and resource requirements.

### 8.2 Cost Optimization

The assessment intentionally uses a cost-conscious configuration, including a small database instance, a limited number of application tasks, and short log-retention periods.

For production, I would evaluate the following trade-offs:

* **Fargate capacity:** Select task sizes based on measured workloads and evaluate Savings Plans for predictable, sustained usage.
* **NAT Gateway:** Place application tasks in private subnets and provide controlled outbound connectivity through NAT gateways where required. A NAT Gateway in each Availability Zone can improve resilience but adds cost.
* **Amazon RDS:** Enable Multi-AZ deployment where the availability requirements justify the additional expense.
* **Log retention and archival:** Retain operational logs in CloudWatch according to incident-response and compliance requirements, and export or archive suitable logs to Amazon S3 when appropriate.
* **Cost monitoring:** Configure AWS Budgets and cost alerts to identify unexpected spending.

### 8.3 High Availability and Resilience

The ALB spans two subnets, but additional configuration is needed to eliminate other single points of failure.

I would consider these improvements:

* **Multiple ECS tasks:** Run at least two tasks across separate Availability Zones, preferably in private subnets.
* **Multi-AZ database deployment:** Enable Multi-AZ for RDS to support database failover. Actual recovery time depends on the database configuration and failure scenario.
* **Remote Terraform state:** Store Terraform state in an S3 backend and configure state locking using a supported mechanism, such as S3 lock files or a compatible locking solution. This avoids relying on a local state file and supports collaborative infrastructure management.
* **HTTPS:** Configure an ACM certificate on the ALB and use HTTPS for public traffic. Configure the frontend hosting and delivery layer to use HTTPS as well.
* **S3 versioning:** Enable versioning for the frontend bucket to help recover from accidental overwrites or deletions.
* **Disaster recovery:** Consider Route 53 failover and a standby AWS Region if the required recovery time objective (RTO) and recovery point objective (RPO) justify the cost and operational complexity.

These improvements would help the application tolerate individual component or Availability Zone failures and respond to increasing demand. The final design should be based on explicit availability, performance, security, and recovery requirements.

## 9. Conclusion

This project demonstrates how to deploy a containerized web application on AWS using Docker, Amazon ECS with Fargate, Amazon ECR, Amazon RDS, Amazon S3, Terraform, and GitHub Actions.

It also demonstrates how Infrastructure as Code and CI/CD automation can make cloud deployments repeatable and easier to manage.

Although the current implementation focuses on the requirements of an assessment, the proposed production improvements provide a roadmap for strengthening scalability, availability, security, observability, and cost management.
