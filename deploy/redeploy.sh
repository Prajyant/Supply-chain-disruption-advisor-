#!/bin/bash
set -e

# =============================================================================
# Quick Redeploy — Build, push, and roll out new version
# =============================================================================
# Usage: cd deploy && ./redeploy.sh
# =============================================================================

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
APP_NAME="supply-chain-advisor"
CLUSTER_NAME="supply-chain-cluster"
SERVICE_NAME="supply-chain-service"
ECR_REPO="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${APP_NAME}"

echo ""
echo "━━━ Redeploying ${APP_NAME} ━━━"
echo ""

echo ">>> Authenticating to ECR..."
aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com

echo ">>> Building image..."
docker build -t ${APP_NAME} ..

echo ">>> Pushing to ECR..."
docker tag ${APP_NAME}:latest ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest

echo ">>> Re-registering task definition..."
sed "s|ACCOUNT_ID|${ACCOUNT_ID}|g" task-definition.json > task-definition-resolved.json
aws ecs register-task-definition \
  --cli-input-json file://task-definition-resolved.json \
  --region ${REGION} > /dev/null
rm -f task-definition-resolved.json

echo ">>> Forcing new deployment..."
aws ecs update-service \
  --cluster ${CLUSTER_NAME} \
  --service ${SERVICE_NAME} \
  --force-new-deployment \
  --region ${REGION} > /dev/null

echo ""
echo "✅ Deployment triggered!"
echo ""
echo "Monitor:"
echo "  aws ecs describe-services --cluster ${CLUSTER_NAME} --services ${SERVICE_NAME} --region ${REGION} --query 'services[0].deployments'"
echo "  aws logs tail /ecs/${APP_NAME} --follow --region ${REGION}"
echo ""
