#!/bin/bash
set -e

# =============================================================================
# Supply Chain Disruption Advisor — FULL ECS Fargate Deployment
# =============================================================================
#
# Deploys everything from scratch:
#   ECR → Docker image → Secrets → IAM → Logs → VPC → SGs → ECS → ALB → Service
#
# Prerequisites:
#   - AWS CLI v2 configured
#   - Docker running
#   - DynamoDB tables created
#
# Usage:
#   cd supply-chain-disruption-advisor/deploy
#   chmod +x deploy.sh create-secrets.sh redeploy.sh
#   ./deploy.sh
#
# =============================================================================

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
APP_NAME="supply-chain-advisor"
CLUSTER_NAME="supply-chain-cluster"
SERVICE_NAME="supply-chain-service"
ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${APP_NAME}"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   Supply Chain Advisor — ECS Fargate Deployment              ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║   Account:  ${ACCOUNT_ID}                          ║"
echo "║   Region:   ${REGION}                                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Create ECR Repository
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 1/12: Creating ECR repository ━━━"
aws ecr create-repository \
  --repository-name ${APP_NAME} \
  --region ${REGION} \
  --image-scanning-configuration scanOnPush=true \
  2>/dev/null && echo "    ✓ Created: ${APP_NAME}" || echo "    ✓ Already exists"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Build and Push Docker Image
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 2/12: Building and pushing Docker image ━━━"
aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo "    Building..."
docker build -t ${APP_NAME} ..
echo "    Pushing to ECR..."
docker tag ${APP_NAME}:latest ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest
echo "    ✓ Image: ${ECR_REPO}:latest"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Store Secrets in Secrets Manager
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 3/12: Storing secrets ━━━"
./create-secrets.sh
SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id ${APP_NAME}/secrets \
  --region ${REGION} \
  --query ARN --output text)
echo "    ARN: ${SECRET_ARN}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Create CloudWatch Log Group
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 4/12: Creating CloudWatch log group ━━━"
aws logs create-log-group \
  --log-group-name /ecs/${APP_NAME} \
  --region ${REGION} 2>/dev/null || true
aws logs put-retention-policy \
  --log-group-name /ecs/${APP_NAME} \
  --retention-in-days 30 \
  --region ${REGION}
echo "    ✓ /ecs/${APP_NAME} (30-day retention)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: Create IAM Roles
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 5/12: Creating IAM roles ━━━"

# --- Task Execution Role ---
aws iam create-role \
  --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || true

aws iam attach-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy 2>/dev/null || true

aws iam put-role-policy \
  --role-name ecsTaskExecutionRole \
  --policy-name SecretsAccess \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [{
      \"Effect\": \"Allow\",
      \"Action\": [\"secretsmanager:GetSecretValue\"],
      \"Resource\": \"arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:${APP_NAME}/*\"
    }]
  }"
echo "    ✓ ecsTaskExecutionRole (pull images + read secrets)"

# --- Task Role (app runtime: DynamoDB + Bedrock + SES) ---
aws iam create-role \
  --role-name supplyChainTaskRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' 2>/dev/null || true

aws iam put-role-policy \
  --role-name supplyChainTaskRole \
  --policy-name AppPermissions \
  --policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Sid\": \"BedrockAccess\",
        \"Effect\": \"Allow\",
        \"Action\": [
          \"bedrock:InvokeModel\",
          \"bedrock:InvokeModelWithResponseStream\"
        ],
        \"Resource\": \"*\"
      },
      {
        \"Sid\": \"SESAccess\",
        \"Effect\": \"Allow\",
        \"Action\": [
          \"ses:SendEmail\",
          \"ses:SendRawEmail\"
        ],
        \"Resource\": \"*\"
      },
      {
        \"Sid\": \"DynamoDBAccess\",
        \"Effect\": \"Allow\",
        \"Action\": [
          \"dynamodb:GetItem\",
          \"dynamodb:PutItem\",
          \"dynamodb:UpdateItem\",
          \"dynamodb:DeleteItem\",
          \"dynamodb:Query\",
          \"dynamodb:Scan\",
          \"dynamodb:BatchGetItem\",
          \"dynamodb:BatchWriteItem\",
          \"dynamodb:DescribeTable\",
          \"dynamodb:ConditionCheckItem\"
        ],
        \"Resource\": [
          \"arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/*\",
          \"arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/*/index/*\"
        ]
      }
    ]
  }"
echo "    ✓ supplyChainTaskRole (DynamoDB + Bedrock + SES)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: VPC Setup
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 6/12: VPC Configuration ━━━"
echo ""
echo "    Create a VPC via AWS Console if you haven't already:"
echo "    VPC → Create VPC → 'VPC and more'"
echo "    Settings: 2 AZs, 2 public subnets, 2 private subnets, 1 NAT gateway"
echo ""
read -p "    VPC ID (vpc-xxxxxxxx): " VPC_ID
read -p "    Public Subnet 1 (subnet-xxxxxxxx): " PUBLIC_SUBNET_1
read -p "    Public Subnet 2 (subnet-xxxxxxxx): " PUBLIC_SUBNET_2
read -p "    Private Subnet 1 (subnet-xxxxxxxx): " PRIVATE_SUBNET_1
read -p "    Private Subnet 2 (subnet-xxxxxxxx): " PRIVATE_SUBNET_2
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: Create Security Groups
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 7/12: Creating security groups ━━━"

ALB_SG=$(aws ec2 create-security-group \
  --group-name ${APP_NAME}-alb-sg \
  --description "ALB - HTTP/HTTPS from internet" \
  --vpc-id ${VPC_ID} \
  --region ${REGION} \
  --query GroupId --output text 2>/dev/null) || \
  ALB_SG=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${APP_NAME}-alb-sg" "Name=vpc-id,Values=${VPC_ID}" \
    --query "SecurityGroups[0].GroupId" --output text --region ${REGION})

aws ec2 authorize-security-group-ingress --group-id ${ALB_SG} --protocol tcp --port 80 --cidr 0.0.0.0/0 --region ${REGION} 2>/dev/null || true
aws ec2 authorize-security-group-ingress --group-id ${ALB_SG} --protocol tcp --port 443 --cidr 0.0.0.0/0 --region ${REGION} 2>/dev/null || true
echo "    ✓ ALB SG: ${ALB_SG}"

ECS_SG=$(aws ec2 create-security-group \
  --group-name ${APP_NAME}-ecs-sg \
  --description "ECS - port 8000 from ALB only" \
  --vpc-id ${VPC_ID} \
  --region ${REGION} \
  --query GroupId --output text 2>/dev/null) || \
  ECS_SG=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=${APP_NAME}-ecs-sg" "Name=vpc-id,Values=${VPC_ID}" \
    --query "SecurityGroups[0].GroupId" --output text --region ${REGION})

aws ec2 authorize-security-group-ingress --group-id ${ECS_SG} --protocol tcp --port 8000 --source-group ${ALB_SG} --region ${REGION} 2>/dev/null || true
echo "    ✓ ECS SG: ${ECS_SG}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8: Create ECS Cluster
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 8/12: Creating ECS cluster ━━━"
aws ecs create-cluster \
  --cluster-name ${CLUSTER_NAME} \
  --region ${REGION} \
  --setting name=containerInsights,value=enabled > /dev/null 2>&1
echo "    ✓ Cluster: ${CLUSTER_NAME}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 9: Create Application Load Balancer
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 9/12: Creating ALB + Target Group ━━━"

ALB_ARN=$(aws elbv2 create-load-balancer \
  --name ${APP_NAME}-alb \
  --subnets ${PUBLIC_SUBNET_1} ${PUBLIC_SUBNET_2} \
  --security-groups ${ALB_SG} \
  --scheme internet-facing \
  --type application \
  --region ${REGION} \
  --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null) || \
  ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names ${APP_NAME}-alb \
    --region ${REGION} \
    --query "LoadBalancers[0].LoadBalancerArn" --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns ${ALB_ARN} \
  --region ${REGION} \
  --query "LoadBalancers[0].DNSName" --output text)

echo "    ✓ ALB: ${ALB_DNS}"

# WebSocket idle timeout
aws elbv2 modify-load-balancer-attributes \
  --load-balancer-arn ${ALB_ARN} \
  --attributes Key=idle_timeout.timeout_seconds,Value=300 \
  --region ${REGION} > /dev/null

# Target Group
TG_ARN=$(aws elbv2 create-target-group \
  --name ${APP_NAME}-tg \
  --protocol HTTP \
  --port 8000 \
  --vpc-id ${VPC_ID} \
  --target-type ip \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 10 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --region ${REGION} \
  --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null) || \
  TG_ARN=$(aws elbv2 describe-target-groups \
    --names ${APP_NAME}-tg \
    --region ${REGION} \
    --query "TargetGroups[0].TargetGroupArn" --output text)

echo "    ✓ Target Group: ${APP_NAME}-tg"

# Listener
aws elbv2 create-listener \
  --load-balancer-arn ${ALB_ARN} \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=${TG_ARN} \
  --region ${REGION} > /dev/null 2>&1 || true
echo "    ✓ Listener: port 80 → target group"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 10: Register Task Definition
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 10/12: Registering task definition ━━━"

sed "s|ACCOUNT_ID|${ACCOUNT_ID}|g" task-definition.json > task-definition-resolved.json

aws ecs register-task-definition \
  --cli-input-json file://task-definition-resolved.json \
  --region ${REGION} > /dev/null

echo "    ✓ Task definition: ${APP_NAME} (1 vCPU / 2 GB)"
echo "    All env vars mapped:"
echo "      - 7 secrets from Secrets Manager"
echo "      - 28 environment variables in task definition"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 11: Create ECS Service
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 11/12: Creating ECS service ━━━"

aws ecs create-service \
  --cluster ${CLUSTER_NAME} \
  --service-name ${SERVICE_NAME} \
  --task-definition ${APP_NAME} \
  --desired-count 2 \
  --launch-type FARGATE \
  --platform-version LATEST \
  --network-configuration "awsvpcConfiguration={subnets=[${PRIVATE_SUBNET_1},${PRIVATE_SUBNET_2}],securityGroups=[${ECS_SG}],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=${TG_ARN},containerName=${APP_NAME},containerPort=8000" \
  --deployment-configuration "minimumHealthyPercent=50,maximumPercent=200" \
  --region ${REGION} > /dev/null 2>&1 && \
  echo "    ✓ Service created: 2 Fargate tasks" || \
  (aws ecs update-service \
    --cluster ${CLUSTER_NAME} \
    --service ${SERVICE_NAME} \
    --force-new-deployment \
    --region ${REGION} > /dev/null 2>&1 && \
  echo "    ✓ Service exists — new deployment triggered")
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 12: Auto Scaling
# ═══════════════════════════════════════════════════════════════════════════════
echo "━━━ Step 12/12: Configuring auto scaling ━━━"

aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/${CLUSTER_NAME}/${SERVICE_NAME} \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 4 \
  --region ${REGION} 2>/dev/null || true

aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/${CLUSTER_NAME}/${SERVICE_NAME} \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleInCooldown": 300,
    "ScaleOutCooldown": 60
  }' \
  --region ${REGION} > /dev/null 2>&1 || true

echo "    ✓ Scaling: 1–4 tasks, target 70% CPU"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════════════════════
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   ✅ DEPLOYMENT COMPLETE                                     ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║                                                               ║"
echo "║   🌐 App:    http://${ALB_DNS}                               "
echo "║   💚 Health: http://${ALB_DNS}/health                        "
echo "║   📖 Docs:   http://${ALB_DNS}/docs                         "
echo "║                                                               ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║   COMMANDS                                                    ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║                                                               ║"
echo "║   Status:  aws ecs describe-services \\                      "
echo "║              --cluster ${CLUSTER_NAME} \\                    "
echo "║              --services ${SERVICE_NAME}                      "
echo "║                                                               ║"
echo "║   Logs:    aws logs tail /ecs/${APP_NAME} --follow           "
echo "║                                                               ║"
echo "║   Redeploy: ./redeploy.sh                                    "
echo "║                                                               ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║   AFTER DEPLOY                                                ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║   1. Update VITE_API_URL in task-definition.json to:         "
echo "║      http://${ALB_DNS}                                       "
echo "║   2. Then run: ./redeploy.sh                                  "
echo "║   3. (Optional) Add HTTPS with ACM certificate               "
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Clean up temp file
rm -f task-definition-resolved.json
