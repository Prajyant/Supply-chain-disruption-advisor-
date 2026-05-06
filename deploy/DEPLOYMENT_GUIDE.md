# ECS Fargate Deployment Guide — Supply Chain Disruption Advisor

## Prerequisites
- AWS CLI v2 installed and configured (`aws configure`)
- Docker installed and running
- AWS account with admin permissions
- DynamoDB tables already created

---

## STEP 1 — Verify Health Endpoint Exists

Your app already has `/health` at `app/api/routes.py`. No changes needed.

---

## STEP 2 — Dockerfile (Already Updated)

```dockerfile
FROM python:3.13-slim

WORKDIR /app

RUN apt-get update && apt-get install -y curl

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## STEP 3 — Test Locally

```bash
cd supply-chain-disruption-advisor

# Build
docker build -t supply-chain-advisor .

# Run
docker run -p 8000:8000 supply-chain-advisor

# Test
curl http://localhost:8000/health
```

If you get `{"status":"healthy"}` → continue.

---

## STEP 4 — Create ECR Repository

```bash
aws ecr create-repository \
  --repository-name supply-chain-advisor \
  --region us-east-1
```

You'll get a URI like:
```
858959712694.dkr.ecr.us-east-1.amazonaws.com/supply-chain-advisor
```

**SAVE THIS URI.**

---

## STEP 5 — Login Docker to ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 858959712694.dkr.ecr.us-east-1.amazonaws.com
```

---

## STEP 6 — Push Docker Image

```bash
# Build
docker build -t supply-chain-advisor .

# Tag
docker tag supply-chain-advisor:latest \
  858959712694.dkr.ecr.us-east-1.amazonaws.com/supply-chain-advisor:latest

# Push
docker push \
  858959712694.dkr.ecr.us-east-1.amazonaws.com/supply-chain-advisor:latest
```

---

## STEP 7 — Create Secrets Manager Secret

```bash
aws secretsmanager create-secret \
  --name supply-chain-advisor/secrets \
  --region us-east-1 \
  --secret-string '{
    "GMAIL_USER": "supplychain.disruptionadvisor@gmail.com",
    "GMAIL_APP_PASSWORD": "esrz cnqb ixbb oiwn",
    "OPENAI_API_KEY": "your-openai-api-key-here",
    "JWT_SECRET": "generate-a-strong-random-secret-for-production",
    "FIREBASE_PROJECT_ID": "supplychain-61cbb",
    "AIS_API_KEY": "3633af3320b652dd0332c5b7317d95d76b64e6ef",
    "EQUASIS_USERNAME": "kaur.taran223@gmail.com",
    "EQUASIS_PASSWORD": "2yyGeBDGa9!c#2y"
  }'
```

**Save the ARN returned.**

---

## STEP 8 — Create VPC

Go to: **AWS Console → VPC → Create VPC**

Choose:
- **VPC and more**
- 2 public subnets
- 2 private subnets
- 1 NAT Gateway

Save:
- VPC ID
- Public subnet IDs (2)
- Private subnet IDs (2)

---

## STEP 9 — Create Security Groups

### ALB Security Group

| Type  | Port | Source    |
|-------|------|-----------|
| HTTP  | 80   | 0.0.0.0/0 |
| HTTPS | 443  | 0.0.0.0/0 |

### ECS Security Group

| Type       | Port | Source             |
|------------|------|--------------------|
| Custom TCP | 8000 | ALB Security Group |

---

## STEP 10 — Create IAM Roles

### A. ECS Task Execution Role

**Purpose:** Pull Docker images, read secrets, write logs

1. IAM → Roles → Create Role
2. Trusted entity: **Elastic Container Service Task**
3. Attach: `AmazonECSTaskExecutionRolePolicy`
4. Add inline policy for Secrets Manager:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["secretsmanager:GetSecretValue"],
    "Resource": "arn:aws:secretsmanager:us-east-1:858959712694:secret:supply-chain-advisor/*"
  }]
}
```

Name it: `ecsTaskExecutionRole`

### B. Application Task Role

**Purpose:** App runtime access to DynamoDB, Bedrock, SES

Attach/inline these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["ses:SendEmail", "ses:SendRawEmail"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-east-1:858959712694:table/*",
        "arn:aws:dynamodb:us-east-1:858959712694:table/*/index/*"
      ]
    }
  ]
}
```

Name it: `supplyChainTaskRole`

---

## STEP 11 — Create CloudWatch Logs

```bash
aws logs create-log-group \
  --log-group-name /ecs/supply-chain-advisor \
  --region us-east-1
```

---

## STEP 12 — Create ECS Cluster

```bash
aws ecs create-cluster \
  --cluster-name supply-chain-cluster \
  --region us-east-1
```

---

## STEP 13 — Create Task Definition

1. Edit `deploy/task-definition.json`
2. Replace all `ACCOUNT_ID` with your actual account ID (858959712694)
3. Replace the Secrets Manager ARN suffix if needed
4. Register:

```bash
aws ecs register-task-definition \
  --cli-input-json file://deploy/task-definition.json \
  --region us-east-1
```

---

## STEP 14 — Create Load Balancer

Go to: **AWS Console → EC2 → Load Balancers**

Create:
- **Application Load Balancer**
- Internet-facing
- Select **public subnets**
- Attach **ALB security group**

---

## STEP 15 — Create Target Group

| Setting           | Value    |
|-------------------|----------|
| Protocol          | HTTP     |
| Port              | 8000     |
| Target type       | IP       |
| Health Check Path | /health  |

---

## STEP 16 — Create ECS Service

Go to: **ECS → Cluster → Create Service**

| Setting          | Value                  |
|------------------|------------------------|
| Launch Type      | FARGATE                |
| Desired Tasks    | 2                      |
| Task Definition  | supply-chain-advisor   |
| Load Balancer    | Attach existing ALB    |

Networking:
- Use **PRIVATE subnets**
- **Disable** public IP
- Attach **ECS security group**

---

## STEP 17 — Test Deployment

```bash
# Check tasks are running
aws ecs list-tasks \
  --cluster supply-chain-cluster \
  --region us-east-1

# Check logs
aws logs tail /ecs/supply-chain-advisor --follow --region us-east-1

# Test health
curl http://YOUR-ALB-DNS/health
```

If you get `{"status":"healthy"}` → **Deployment successful** 🎉

---

## STEP 18 — Add HTTPS

1. Go to **AWS Certificate Manager**
2. Request a public certificate for your domain
3. Validate via DNS
4. Go to ALB → Add HTTPS listener (port 443)
5. Attach the certificate
6. (Optional) Redirect HTTP → HTTPS

---

## STEP 19 — Future Deployments

Whenever code changes:

```bash
# Build and push
docker build -t supply-chain-advisor .
docker tag supply-chain-advisor:latest \
  858959712694.dkr.ecr.us-east-1.amazonaws.com/supply-chain-advisor:latest
docker push \
  858959712694.dkr.ecr.us-east-1.amazonaws.com/supply-chain-advisor:latest

# Redeploy
aws ecs update-service \
  --cluster supply-chain-cluster \
  --service supply-chain-service \
  --force-new-deployment \
  --region us-east-1
```

---

## Environment Variable Mapping

### Secrets Manager (sensitive — injected automatically by ECS):
| Variable | Value |
|----------|-------|
| GMAIL_USER | supplychain.disruptionadvisor@gmail.com |
| GMAIL_APP_PASSWORD | (stored securely) |
| OPENAI_API_KEY | (stored securely) |
| JWT_SECRET | (stored securely) |
| FIREBASE_PROJECT_ID | supplychain-61cbb |
| AIS_API_KEY | (stored securely) |
| EQUASIS_USERNAME | (stored securely) |
| EQUASIS_PASSWORD | (stored securely) |

### Task Definition `environment` (non-sensitive — in task-definition.json):
| Variable | Value |
|----------|-------|
| AWS_REGION | us-east-1 |
| BEDROCK_MODEL_ID | us.anthropic.claude-sonnet-4-20250514-v1:0 |
| GEMINI_MODEL | gemini-1.5-flash |
| AIS_PROVIDER | aisstream |
| WATCHLIST_CSV_PATH | ./watchlist.csv |
| VESSEL_POLL_INTERVAL_SECONDS | 10 |
| VESSEL_SILENCE_THRESHOLD_HOURS | 6 |
| VESSEL_STALE_THRESHOLD_HOURS | 1 |
| VESSEL_HISTORY_RETENTION_DAYS | 90 |
| VESSEL_IDENTITY_CACHE_DAYS | 30 |
| VESSEL_REGISTRY_CACHE_DB | data/vessel_registry_cache.db |
| VESSEL_REGISTRY_CACHE_DAYS | 30 |
| SANCTIONS_CACHE_DB | data/sanctions_cache.db |
| SANCTIONS_CACHE_HOURS | 24 |
| TARIFF_CACHE_DB | data/tariff_cache.db |
| TARIFF_CACHE_DAYS | 7 |
| SES_SENDER_EMAIL | supplychain.disruptionadvisor@gmail.com |
| SES_ALERT_RECIPIENTS | kashish.xa@gmail.com |
| SES_RECIPIENTS_OPERATIONS | taranpreet.kaur591@gmail.com |
| SES_RECIPIENTS_FINANCE | kashish.xa@gmail.com |
| SES_RECIPIENTS_ANALYST | pajusiag@gmail.com |
| SES_RECIPIENTS_EXECUTIVE | sparshnautiyal2005@gmail.com |
| SES_REGION | us-east-1 |
| VITE_API_URL | (set to ALB DNS after deploy) |
| STREAMLIT_API_URL | (set to ALB DNS after deploy) |
| VITE_FIREBASE_API_KEY | AIzaSyCFZn3bGVmPDH3i01F2zYbLMDRKZkz0_AA |
| VITE_FIREBASE_AUTH_DOMAIN | supplychain-61cbb.firebaseapp.com |
| VITE_FIREBASE_PROJECT_ID | supplychain-61cbb |
| VITE_FIREBASE_STORAGE_BUCKET | supplychain-61cbb.firebasestorage.app |
| VITE_FIREBASE_MESSAGING_SENDER_ID | 142814059318 |
| VITE_FIREBASE_APP_ID | 1:142814059318:web:dfc0d6fa2c8843d796f197 |

### NOT NEEDED on Fargate (task role provides credentials):
| Variable | Why |
|----------|-----|
| AWS_ACCESS_KEY_ID | Task role handles auth |
| AWS_SECRET_ACCESS_KEY | Task role handles auth |
| AWS_SESSION_TOKEN | Task role handles auth |
| DATABASE_URL | Using DynamoDB via SDK |
