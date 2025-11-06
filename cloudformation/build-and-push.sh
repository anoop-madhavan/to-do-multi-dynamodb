#!/bin/bash

# Build and Push Docker Images to ECR
# Usage: ./build-and-push.sh [version] [region]
# Example: ./build-and-push.sh v1.0.0 us-east-1

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
VERSION=${1:-latest}
REGION=${2:-us-east-1}
APP_NAME="todo-app"

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

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Get AWS Account ID
if ! AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null); then
    print_error "Failed to get AWS Account ID. Please configure AWS CLI."
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     Todo App - Docker Build and Push Script                   ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Version: $VERSION"
echo "  Region: $REGION"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  ECR Registry: $ECR_REGISTRY"
echo ""

# Check if ECR repository exists
print_info "Checking if ECR repository exists..."
if ! aws ecr describe-repositories --repository-names $APP_NAME --region $REGION &> /dev/null; then
    print_error "ECR repository '$APP_NAME' does not exist in region $REGION"
    echo "Please create the ECR repository first using CloudFormation:"
    echo "  cd cloudformation"
    echo "  ./deploy-all.sh dev $REGION"
    exit 1
fi
print_success "ECR repository found"

# Step 1: Login to ECR
print_step "Step 1/4: Logging in to ECR"
if aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY; then
    print_success "Successfully logged in to ECR"
else
    print_error "Failed to login to ECR"
    exit 1
fi

# Step 2: Build Backend
print_step "Step 2/4: Building Backend Docker Image"
cd ..  # Go to project root
print_info "Building backend:${VERSION}..."

if docker buildx build --platform linux/amd64 -t ${APP_NAME}-backend:${VERSION} ./backend; then
    print_success "Backend image built successfully"
    
    # Tag images
    docker tag ${APP_NAME}-backend:${VERSION} ${ECR_REGISTRY}/${APP_NAME}:backend-${VERSION}
    docker tag ${APP_NAME}-backend:${VERSION} ${ECR_REGISTRY}/${APP_NAME}:backend-latest
    print_success "Backend images tagged"
else
    print_error "Failed to build backend image"
    exit 1
fi

# Step 3: Build Frontend
print_step "Step 3/4: Building Frontend Docker Image"
print_info "Building frontend:${VERSION}..."

if docker buildx build --platform linux/amd64 -t ${APP_NAME}-frontend:${VERSION} ./frontend; then
    print_success "Frontend image built successfully"
    
    # Tag images
    docker tag ${APP_NAME}-frontend:${VERSION} ${ECR_REGISTRY}/${APP_NAME}:frontend-${VERSION}
    docker tag ${APP_NAME}-frontend:${VERSION} ${ECR_REGISTRY}/${APP_NAME}:frontend-latest
    print_success "Frontend images tagged"
else
    print_error "Failed to build frontend image"
    exit 1
fi

# Step 4: Push to ECR
print_step "Step 4/4: Pushing Images to ECR"

print_info "Pushing backend images..."
docker push ${ECR_REGISTRY}/${APP_NAME}:backend-${VERSION}
docker push ${ECR_REGISTRY}/${APP_NAME}:backend-latest
print_success "Backend images pushed to ECR"

print_info "Pushing frontend images..."
docker push ${ECR_REGISTRY}/${APP_NAME}:frontend-${VERSION}
docker push ${ECR_REGISTRY}/${APP_NAME}:frontend-latest
print_success "Frontend images pushed to ECR"

# Summary
echo -e "\n${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        🎉 Build and Push Completed Successfully! 🎉            ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Images Pushed:${NC}"
echo "  Backend:"
echo "    - ${ECR_REGISTRY}/${APP_NAME}:backend-${VERSION}"
echo "    - ${ECR_REGISTRY}/${APP_NAME}:backend-latest"
echo "  Frontend:"
echo "    - ${ECR_REGISTRY}/${APP_NAME}:frontend-${VERSION}"
echo "    - ${ECR_REGISTRY}/${APP_NAME}:frontend-latest"
echo ""

echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. If stacks are already deployed, force new deployment:"
echo "     aws ecs update-service --cluster dev-${APP_NAME}-cluster --service dev-${APP_NAME}-backend-service --force-new-deployment --region $REGION"
echo "     aws ecs update-service --cluster dev-${APP_NAME}-cluster --service dev-${APP_NAME}-frontend-service --force-new-deployment --region $REGION"
echo ""
echo "  2. Or update task definitions with specific version:"
echo "     Update ECRImageURI parameter in task definition stacks"
echo ""
echo "  3. Verify images in ECR:"
echo "     aws ecr list-images --repository-name ${APP_NAME} --region $REGION"
echo ""

print_success "All images built and pushed successfully! 🚀"

