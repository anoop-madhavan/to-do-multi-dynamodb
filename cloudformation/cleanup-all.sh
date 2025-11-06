#!/bin/bash

# Cleanup All CloudFormation Stacks for Todo App
# Usage: ./cleanup-all.sh [environment] [region]
# Example: ./cleanup-all.sh dev us-east-1

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

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Environment must be dev, staging, or prod${NC}"
    echo "Usage: $0 [environment] [region]"
    exit 1
fi

# Function to print colored output
print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}$1${NC}"
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

echo -e "${RED}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     ⚠️  Todo App - CloudFormation Cleanup Script ⚠️            ║
║                                                                ║
║     THIS WILL DELETE ALL RESOURCES!                           ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
echo "  App Name: $APP_NAME"
echo ""

echo -e "${RED}WARNING: This will delete the following stacks:${NC}"
echo "  1. ${ENVIRONMENT}-${APP_NAME}-frontend-service"
echo "  2. ${ENVIRONMENT}-${APP_NAME}-backend-service"
echo "  3. ${ENVIRONMENT}-${APP_NAME}-frontend-task-definition"
echo "  4. ${ENVIRONMENT}-${APP_NAME}-backend-task-definition"
echo "  5. ${ENVIRONMENT}-${APP_NAME}-alb"
echo "  6. ${ENVIRONMENT}-${APP_NAME}-ecs-cluster"
echo "  7. ${ENVIRONMENT}-${APP_NAME}-security-groups"
echo "  8. ${ENVIRONMENT}-shared-vpc"
echo "  9. ${ENVIRONMENT}-${APP_NAME}-ecr (optional)"
echo ""

read -p "Are you sure you want to delete all resources? Type 'DELETE' to confirm: " -r
echo
if [[ ! $REPLY == "DELETE" ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Function to delete stack
delete_stack() {
    local stack_name=$1
    local description=$2
    
    print_step "$description"
    
    if aws cloudformation describe-stacks --stack-name $stack_name --region $REGION &> /dev/null; then
        print_info "Deleting stack: $stack_name"
        aws cloudformation delete-stack --stack-name $stack_name --region $REGION
        
        print_info "Waiting for stack deletion to complete..."
        if aws cloudformation wait stack-delete-complete --stack-name $stack_name --region $REGION 2>/dev/null; then
            print_success "Stack deleted: $stack_name"
        else
            print_error "Failed to delete stack: $stack_name"
            echo "Check the CloudFormation console for details"
        fi
    else
        print_info "Stack does not exist: $stack_name (skipping)"
    fi
}

# Step 1: Delete Frontend Service
delete_stack "${ENVIRONMENT}-${APP_NAME}-frontend-service" "Step 1/9: Deleting Frontend ECS Service"

# Step 2: Delete Backend Service
delete_stack "${ENVIRONMENT}-${APP_NAME}-backend-service" "Step 2/9: Deleting Backend ECS Service"

# Step 3: Delete Frontend Task Definition
delete_stack "${ENVIRONMENT}-${APP_NAME}-frontend-task-definition" "Step 3/9: Deleting Frontend Task Definition"

# Step 4: Delete Backend Task Definition
delete_stack "${ENVIRONMENT}-${APP_NAME}-backend-task-definition" "Step 4/9: Deleting Backend Task Definition"

# Step 5: Delete ALB
delete_stack "${ENVIRONMENT}-${APP_NAME}-alb" "Step 5/9: Deleting Application Load Balancer"

# Step 6: Delete ECS Cluster
delete_stack "${ENVIRONMENT}-${APP_NAME}-ecs-cluster" "Step 6/9: Deleting ECS Cluster"

# Step 7: Delete Security Groups
delete_stack "${ENVIRONMENT}-${APP_NAME}-security-groups" "Step 7/9: Deleting Security Groups"

# Step 8: Delete VPC
delete_stack "${ENVIRONMENT}-shared-vpc" "Step 8/9: Deleting VPC"

# Step 9: Delete ECR (optional)
print_step "Step 9/9: Deleting ECR Repository (Optional)"
echo -e "${YELLOW}WARNING: This will delete all Docker images in the ECR repository!${NC}"
read -p "Do you want to delete the ECR repository? (yes/no): " -n 3 -r
echo
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    # First, delete all images in the repository
    print_info "Deleting all images in ECR repository..."
    IMAGE_IDS=$(aws ecr list-images \
        --repository-name $APP_NAME \
        --region $REGION \
        --query 'imageIds[*]' \
        --output json 2>/dev/null || echo "[]")
    
    if [[ "$IMAGE_IDS" != "[]" ]]; then
        aws ecr batch-delete-image \
            --repository-name $APP_NAME \
            --image-ids "$IMAGE_IDS" \
            --region $REGION 2>/dev/null || true
        print_success "All images deleted from ECR"
    fi
    
    # Now delete the stack
    delete_stack "${ENVIRONMENT}-${APP_NAME}-ecr" "Deleting ECR Repository"
else
    print_info "Skipping ECR deletion. Repository will remain with all images."
fi

# Cleanup Summary
echo -e "\n${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              🗑️  Cleanup Completed Successfully! 🗑️             ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Cleanup Summary:${NC}"
echo "  Environment: $ENVIRONMENT"
echo "  Region: $REGION"
echo ""

echo -e "${YELLOW}Verify Cleanup:${NC}"
echo "  List remaining stacks:"
echo "    aws cloudformation list-stacks --region $REGION --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query 'StackSummaries[?contains(StackName, \`${ENVIRONMENT}\`)].StackName'"
echo ""

echo -e "${YELLOW}Check for Remaining Resources:${NC}"
echo "  1. CloudFormation Stacks: https://console.aws.amazon.com/cloudformation"
echo "  2. ECS Clusters: https://console.aws.amazon.com/ecs"
echo "  3. Load Balancers: https://console.aws.amazon.com/ec2/v2/home?region=$REGION#LoadBalancers"
echo "  4. VPCs: https://console.aws.amazon.com/vpc"
echo "  5. ECR Repositories: https://console.aws.amazon.com/ecr"
echo ""

print_success "All stacks deleted successfully! 🧹"

