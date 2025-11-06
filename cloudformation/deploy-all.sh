#!/bin/bash

# Deploy All CloudFormation Stacks for Todo App
# Usage: ./deploy-all.sh [environment] [region]
# Example: ./deploy-all.sh dev us-east-1

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}
APP_NAME="todo-app"

# Load environment variables from .env file if it exists
if [ -f "../.env" ]; then
    print_info "Loading environment variables from .env file..."
    export $(grep -v '^#' ../.env | xargs)
    print_success "Environment variables loaded"
fi

# Set defaults if not provided in .env
APP_NAME_ENV=${APP_NAME:-"Todo SaaS"}
APP_DESCRIPTION_ENV=${APP_DESCRIPTION:-"Simple, clean, and efficient task management"}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Environment must be dev, staging, or prod${NC}"
    echo "Usage: $0 [environment] [region]"
    exit 1
fi

# Function to print colored output
print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     Todo App - CloudFormation Deployment Script               ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
echo "  App Name: $APP_NAME"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo ""

read -p "Continue with deployment? (yes/no): " -n 3 -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Step 1: Create ECR Repository
print_step "Step 1/9: Creating ECR Repository"
STACK_NAME="${ENVIRONMENT}-${APP_NAME}-ecr"
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack $STACK_NAME already exists. Skipping..."
else
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://ecr-repository.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=AppName,ParameterValue=$APP_NAME \
            ParameterKey=ImageTagMutability,ParameterValue=MUTABLE \
            ParameterKey=ScanOnPush,ParameterValue=enabled \
            ParameterKey=LifecyclePolicyEnabled,ParameterValue=enabled \
            ParameterKey=MaxImageCount,ParameterValue=10 \
        --region $REGION
    
    print_info "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    print_success "ECR Repository created successfully"
fi

# Get ECR Repository URI
ECR_REPO_URI=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`RepositoryUri`].OutputValue' \
    --output text)
echo "  ECR Repository: $ECR_REPO_URI"

# Step 2: Create VPC
print_step "Step 2/9: Creating VPC and Networking"
STACK_NAME="${ENVIRONMENT}-shared-vpc"
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack $STACK_NAME already exists. Skipping..."
else
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://vpc-shared.yaml \
        --parameters \
            ParameterKey=EnvironmentName,ParameterValue=$ENVIRONMENT \
            ParameterKey=VpcCIDR,ParameterValue=10.0.0.0/16 \
            ParameterKey=PublicSubnet1CIDR,ParameterValue=10.0.1.0/24 \
            ParameterKey=PublicSubnet2CIDR,ParameterValue=10.0.2.0/24 \
            ParameterKey=PrivateSubnet1CIDR,ParameterValue=10.0.3.0/24 \
            ParameterKey=PrivateSubnet2CIDR,ParameterValue=10.0.4.0/24 \
        --region $REGION
    
    print_info "Waiting for stack creation to complete (this may take 3-5 minutes)..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    print_success "VPC created successfully"
fi

# Step 3: Create Security Groups
print_step "Step 3/9: Creating Security Groups"
STACK_NAME="${ENVIRONMENT}-${APP_NAME}-security-groups"
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack $STACK_NAME already exists. Skipping..."
else
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://security-groups.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=AppName,ParameterValue=$APP_NAME \
            ParameterKey=BackendPort,ParameterValue=4000 \
            ParameterKey=FrontendPort,ParameterValue=3000 \
        --region $REGION
    
    print_info "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    print_success "Security Groups created successfully"
fi

# Step 4: Create ECS Cluster
print_step "Step 4/9: Creating ECS Cluster"
STACK_NAME="${ENVIRONMENT}-${APP_NAME}-ecs-cluster"
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack $STACK_NAME already exists. Skipping..."
else
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://ecs-cluster.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=AppName,ParameterValue=$APP_NAME \
            ParameterKey=EnableContainerInsights,ParameterValue=enabled \
        --region $REGION
    
    print_info "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    print_success "ECS Cluster created successfully"
fi

# Step 5: Create Application Load Balancer
print_step "Step 5/9: Creating Application Load Balancer"
STACK_NAME="${ENVIRONMENT}-${APP_NAME}-alb"
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack $STACK_NAME already exists. Skipping..."
else
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://alb.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=AppName,ParameterValue=$APP_NAME \
            ParameterKey=BackendPort,ParameterValue=4000 \
            ParameterKey=FrontendPort,ParameterValue=3000 \
            ParameterKey=BackendHealthCheckPath,ParameterValue=/api/health \
            ParameterKey=FrontendHealthCheckPath,ParameterValue=/ \
            ParameterKey=HealthCheckInterval,ParameterValue=30 \
            ParameterKey=HealthCheckTimeout,ParameterValue=5 \
            ParameterKey=HealthyThresholdCount,ParameterValue=2 \
            ParameterKey=UnhealthyThresholdCount,ParameterValue=3 \
        --region $REGION
    
    print_info "Waiting for stack creation to complete (this may take 2-3 minutes)..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    print_success "Application Load Balancer created successfully"
fi

# Get ALB DNS
ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
    --output text)
echo "  ALB DNS: http://$ALB_DNS"

# Check if Docker images exist
print_step "Checking Docker Images in ECR"
BACKEND_IMAGE="${ECR_REGISTRY}/${APP_NAME}:backend-latest"
FRONTEND_IMAGE="${ECR_REGISTRY}/${APP_NAME}:frontend-latest"

if aws ecr describe-images --repository-name $APP_NAME --image-ids imageTag=backend-latest --region $REGION &> /dev/null; then
    print_success "Backend image found: $BACKEND_IMAGE"
else
    print_error "Backend image not found in ECR!"
    echo "Please build and push your backend image first:"
    echo "  cd ../backend"
    echo "  docker buildx build --platform linux/amd64 -t $BACKEND_IMAGE ."
    echo "  aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"
    echo "  docker push $BACKEND_IMAGE"
    exit 1
fi

if aws ecr describe-images --repository-name $APP_NAME --image-ids imageTag=frontend-latest --region $REGION &> /dev/null; then
    print_success "Frontend image found: $FRONTEND_IMAGE"
else
    print_error "Frontend image not found in ECR!"
    echo "Please build and push your frontend image first:"
    echo "  cd ../frontend"
    echo "  docker buildx build --platform linux/amd64 -t $FRONTEND_IMAGE ."
    echo "  aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"
    echo "  docker push $FRONTEND_IMAGE"
    exit 1
fi

# Step 6: Create Backend Task Definition
print_step "Step 6/9: Creating Backend Task Definition"
STACK_NAME="${ENVIRONMENT}-${APP_NAME}-backend-task-definition"
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack $STACK_NAME already exists. Skipping..."
else
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://ecs-task-definition-backend.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=AppName,ParameterValue=$APP_NAME \
            ParameterKey=ECRImageURI,ParameterValue=$BACKEND_IMAGE \
            ParameterKey=BackendPort,ParameterValue=4000 \
            ParameterKey=TaskCPU,ParameterValue=256 \
            ParameterKey=TaskMemory,ParameterValue=512 \
            ParameterKey=AppNameEnv,ParameterValue="${APP_NAME_ENV}" \
            ParameterKey=AppDescriptionEnv,ParameterValue="${APP_DESCRIPTION_ENV}" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION
    
    print_info "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    print_success "Backend Task Definition created successfully"
fi

# Step 7: Create Frontend Task Definition
print_step "Step 7/9: Creating Frontend Task Definition"
STACK_NAME="${ENVIRONMENT}-${APP_NAME}-frontend-task-definition"
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack $STACK_NAME already exists. Skipping..."
else
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://ecs-task-definition-frontend.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=AppName,ParameterValue=$APP_NAME \
            ParameterKey=ECRImageURI,ParameterValue=$FRONTEND_IMAGE \
            ParameterKey=FrontendPort,ParameterValue=3000 \
            ParameterKey=TaskCPU,ParameterValue=256 \
            ParameterKey=TaskMemory,ParameterValue=512 \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION
    
    print_info "Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    print_success "Frontend Task Definition created successfully"
fi

# Step 8: Create Backend Service
print_step "Step 8/9: Creating Backend ECS Service"
STACK_NAME="${ENVIRONMENT}-${APP_NAME}-backend-service"
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack $STACK_NAME already exists. Skipping..."
else
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://ecs-service-backend.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=AppName,ParameterValue=$APP_NAME \
            ParameterKey=DesiredCount,ParameterValue=2 \
            ParameterKey=MinTasks,ParameterValue=1 \
            ParameterKey=MaxTasks,ParameterValue=4 \
            ParameterKey=TargetCPUUtilization,ParameterValue=70 \
            ParameterKey=BackendPort,ParameterValue=4000 \
        --region $REGION
    
    print_info "Waiting for stack creation to complete (this may take 2-3 minutes)..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    print_success "Backend Service created successfully"
fi

# Step 9: Create Frontend Service
print_step "Step 9/9: Creating Frontend ECS Service"
STACK_NAME="${ENVIRONMENT}-${APP_NAME}-frontend-service"
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION &> /dev/null; then
    print_info "Stack $STACK_NAME already exists. Skipping..."
else
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://ecs-service-frontend.yaml \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=AppName,ParameterValue=$APP_NAME \
            ParameterKey=DesiredCount,ParameterValue=2 \
            ParameterKey=MinTasks,ParameterValue=1 \
            ParameterKey=MaxTasks,ParameterValue=4 \
            ParameterKey=TargetCPUUtilization,ParameterValue=70 \
            ParameterKey=FrontendPort,ParameterValue=3000 \
        --region $REGION
    
    print_info "Waiting for stack creation to complete (this may take 2-3 minutes)..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION
    print_success "Frontend Service created successfully"
fi

# Deployment Summary
echo -e "\n${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              🎉 Deployment Completed Successfully! 🎉          ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Deployment Summary:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
echo "  Application URL: http://$ALB_DNS"
echo "  Backend API: http://$ALB_DNS/api/health"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Wait 2-3 minutes for ECS tasks to start"
echo "  2. Verify backend: curl http://$ALB_DNS/api/health"
echo "  3. Open frontend: http://$ALB_DNS"
echo "  4. Check ECS services:"
echo "     aws ecs describe-services --cluster ${ENVIRONMENT}-${APP_NAME}-cluster --services ${ENVIRONMENT}-${APP_NAME}-backend-service --region $REGION"
echo "     aws ecs describe-services --cluster ${ENVIRONMENT}-${APP_NAME}-cluster --services ${ENVIRONMENT}-${APP_NAME}-frontend-service --region $REGION"
echo ""

echo -e "${YELLOW}Monitor Logs:${NC}"
echo "  Backend:  aws logs tail /ecs/${ENVIRONMENT}-${APP_NAME}-backend --follow --region $REGION"
echo "  Frontend: aws logs tail /ecs/${ENVIRONMENT}-${APP_NAME}-frontend --follow --region $REGION"
echo ""

print_success "All stacks deployed successfully! 🚀"

