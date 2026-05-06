#!/bin/bash
set -e

# =============================================================================
# Create Secrets in AWS Secrets Manager with REAL values
# =============================================================================
# Run this ONCE before deploying. To update later:
#   aws secretsmanager update-secret --secret-id supply-chain-advisor/secrets --secret-string '{...}'
# =============================================================================

REGION="us-east-1"
APP_NAME="supply-chain-advisor"

echo ">>> Creating secret: ${APP_NAME}/secrets"

aws secretsmanager create-secret \
  --name ${APP_NAME}/secrets \
  --region ${REGION} \
  --secret-string '{
    "GMAIL_USER": "supplychain.disruptionadvisor@gmail.com",
    "GMAIL_APP_PASSWORD": "esrz cnqb ixbb oiwn",
    "JWT_SECRET": "generate-a-64-char-random-string-here-for-production",
    "FIREBASE_PROJECT_ID": "supplychain-61cbb",
    "AIS_API_KEY": "3633af3320b652dd0332c5b7317d95d76b64e6ef",
    "EQUASIS_USERNAME": "kaur.taran223@gmail.com",
    "EQUASIS_PASSWORD": "2yyGeBDGa9!c#2y"
  }' \
  2>/dev/null && echo "✓ Secret created" || echo "✓ Secret already exists"

echo ""
echo "To update values later:"
echo "  aws secretsmanager update-secret --secret-id ${APP_NAME}/secrets --region ${REGION} --secret-string '{...}'"
echo ""
echo "To view current values:"
echo "  aws secretsmanager get-secret-value --secret-id ${APP_NAME}/secrets --region ${REGION}"
