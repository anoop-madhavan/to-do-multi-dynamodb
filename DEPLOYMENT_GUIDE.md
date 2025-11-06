# AWS CloudFormation Deployment Guide - Todo App

This guide provides step-by-step instructions to deploy the Todo App infrastructure using AWS CloudFormation.

## Prerequisites

- AWS CLI installed and configured
- Docker installed (for building and pushing container images)
- Appropriate AWS credentials with permissions to create resources
- Your application code ready to be containerized

## Deployment Order

The stacks must be deployed in the following order due to dependencies:

1. **ECR Repository** - For storing Docker images
2. **VPC & Networking** - Foundation for all resources
3. **Security Groups** - Network security rules
4. **ECS Cluster** - Container orchestration cluster
5. **Application Load Balancer** - Traffic distribution
6. **ECS Task Definitions** - Backend and Frontend container configurations
7. **ECS Services** - Running containers with auto-scaling

---

## Step 1: Create ECR Repository

Create the ECR repository to store your Docker images.

```bash
aws cloudformation create-stack \
    --stack-name dev-todo-app-ecr \
    --template-body file://cloudformation/ecr-repository.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=AppName,ParameterValue=todo-app \
        ParameterKey=ImageTagMutability,ParameterValue=MUTABLE \
        ParameterKey=ScanOnPush,ParameterValue=enabled \
        ParameterKey=LifecyclePolicyEnabled,ParameterValue=enabled \
        ParameterKey=MaxImageCount,ParameterValue=10 \
    --region us-east-1
```

**Wait for completion:**

```bash
aws cloudformation wait stack-create-complete --stack-name dev-todo-app-ecr --region us-east-1
```

**Get ECR Repository URI:**

```bash
aws cloudformation describe-stacks \
    --stack-name dev-todo-app-ecr \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`RepositoryUri`].OutputValue' \
    --output text
```

---

## Step 2: Build and Push Docker Images

Before proceeding, build and push your backend and frontend images to ECR.

```bash
# Get your AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
VERSION="v1.0.0"

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Build Backend Docker image
echo "Building backend:${VERSION}..."
cd backend
docker buildx build --platform linux/amd64 -t todo-app-backend:${VERSION} .
docker tag todo-app-backend:${VERSION} ${ECR_REGISTRY}/todo-app:backend-${VERSION}
docker tag todo-app-backend:${VERSION} ${ECR_REGISTRY}/todo-app:backend-latest
cd ..

# Build Frontend Docker image
echo "Building frontend:${VERSION}..."
cd frontend
docker buildx build --platform linux/amd64 -t todo-app-frontend:${VERSION} .
docker tag todo-app-frontend:${VERSION} ${ECR_REGISTRY}/todo-app:frontend-${VERSION}
docker tag todo-app-frontend:${VERSION} ${ECR_REGISTRY}/todo-app:frontend-latest
cd ..

# Push to ECR
echo "Pushing backend images to ECR..."
docker push ${ECR_REGISTRY}/todo-app:backend-${VERSION}
docker push ${ECR_REGISTRY}/todo-app:backend-latest

echo "Pushing frontend images to ECR..."
docker push ${ECR_REGISTRY}/todo-app:frontend-${VERSION}
docker push ${ECR_REGISTRY}/todo-app:frontend-latest

echo "✅ Successfully pushed all images to ECR"
```

---

## Step 3: Create VPC and Networking

Create the VPC with public and private subnets.

```bash
aws cloudformation create-stack \
    --stack-name dev-shared-vpc \
    --template-body file://cloudformation/vpc-shared.yaml \
    --parameters \
        ParameterKey=EnvironmentName,ParameterValue=dev \
        ParameterKey=VpcCIDR,ParameterValue=10.0.0.0/16 \
        ParameterKey=PublicSubnet1CIDR,ParameterValue=10.0.1.0/24 \
        ParameterKey=PublicSubnet2CIDR,ParameterValue=10.0.2.0/24 \
        ParameterKey=PrivateSubnet1CIDR,ParameterValue=10.0.3.0/24 \
        ParameterKey=PrivateSubnet2CIDR,ParameterValue=10.0.4.0/24 \
    --region us-east-1
```

**Wait for completion:**

```bash
aws cloudformation wait stack-create-complete --stack-name dev-shared-vpc --region us-east-1
```

---

## Step 4: Create Security Groups

Create security groups for ALB, Backend ECS, and Frontend ECS tasks.

```bash
aws cloudformation create-stack \
    --stack-name dev-todo-app-security-groups \
    --template-body file://cloudformation/security-groups.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=AppName,ParameterValue=todo-app \
        ParameterKey=BackendPort,ParameterValue=4000 \
        ParameterKey=FrontendPort,ParameterValue=3000 \
    --region us-east-1
```

**Wait for completion:**

```bash
aws cloudformation wait stack-create-complete --stack-name dev-todo-app-security-groups --region us-east-1
```

---

## Step 5: Create ECS Cluster

Create the ECS Fargate cluster.

```bash
aws cloudformation create-stack \
    --stack-name dev-todo-app-ecs-cluster \
    --template-body file://cloudformation/ecs-cluster.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=AppName,ParameterValue=todo-app \
        ParameterKey=EnableContainerInsights,ParameterValue=enabled \
    --region us-east-1
```

**Wait for completion:**

```bash
aws cloudformation wait stack-create-complete --stack-name dev-todo-app-ecs-cluster --region us-east-1
```

---

## Step 6: Create Application Load Balancer

Create the ALB to distribute traffic to your containers.

```bash
aws cloudformation create-stack \
    --stack-name dev-todo-app-alb \
    --template-body file://cloudformation/alb.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=AppName,ParameterValue=todo-app \
        ParameterKey=BackendPort,ParameterValue=4000 \
        ParameterKey=FrontendPort,ParameterValue=3000 \
        ParameterKey=BackendHealthCheckPath,ParameterValue=/api/health \
        ParameterKey=FrontendHealthCheckPath,ParameterValue=/ \
        ParameterKey=HealthCheckInterval,ParameterValue=30 \
        ParameterKey=HealthCheckTimeout,ParameterValue=5 \
        ParameterKey=HealthyThresholdCount,ParameterValue=2 \
        ParameterKey=UnhealthyThresholdCount,ParameterValue=3 \
    --region us-east-1
```

**Wait for completion:**

```bash
aws cloudformation wait stack-create-complete --stack-name dev-todo-app-alb --region us-east-1
```

**Get ALB DNS Name:**

```bash
ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name dev-todo-app-alb \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
    --output text)

echo "Application URL: http://${ALB_DNS}"
```

---

## Step 7: Create ECS Task Definitions

Create the task definitions for backend and frontend containers.

### Backend Task Definition

```bash
# Get ECR Image URI
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_IMAGE_URI_BACKEND="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app:backend-latest"

aws cloudformation create-stack \
    --stack-name dev-todo-app-backend-task-definition \
    --template-body file://cloudformation/ecs-task-definition-backend.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=AppName,ParameterValue=todo-app \
        ParameterKey=ECRImageURI,ParameterValue=${ECR_IMAGE_URI_BACKEND} \
        ParameterKey=BackendPort,ParameterValue=4000 \
        ParameterKey=TaskCPU,ParameterValue=256 \
        ParameterKey=TaskMemory,ParameterValue=512 \
        ParameterKey=AppNameEnv,ParameterValue='Todo SaaS' \
        ParameterKey=AppDescriptionEnv,ParameterValue='Simple, clean, and efficient task management' \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1
```

**Wait for completion:**

```bash
aws cloudformation wait stack-create-complete --stack-name dev-todo-app-backend-task-definition --region us-east-1
```

### Frontend Task Definition

```bash
# Get ECR Image URI
ECR_IMAGE_URI_FRONTEND="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app:frontend-latest"

aws cloudformation create-stack \
    --stack-name dev-todo-app-frontend-task-definition \
    --template-body file://cloudformation/ecs-task-definition-frontend.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=AppName,ParameterValue=todo-app \
        ParameterKey=ECRImageURI,ParameterValue=${ECR_IMAGE_URI_FRONTEND} \
        ParameterKey=FrontendPort,ParameterValue=3000 \
        ParameterKey=TaskCPU,ParameterValue=256 \
        ParameterKey=TaskMemory,ParameterValue=512 \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1
```

**Wait for completion:**

```bash
aws cloudformation wait stack-create-complete --stack-name dev-todo-app-frontend-task-definition --region us-east-1
```

---

## Step 8: Create ECS Services

Create the ECS services with auto-scaling.

### Backend Service

```bash
aws cloudformation create-stack \
    --stack-name dev-todo-app-backend-service \
    --template-body file://cloudformation/ecs-service-backend.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=AppName,ParameterValue=todo-app \
        ParameterKey=DesiredCount,ParameterValue=2 \
        ParameterKey=MinTasks,ParameterValue=1 \
        ParameterKey=MaxTasks,ParameterValue=4 \
        ParameterKey=TargetCPUUtilization,ParameterValue=70 \
        ParameterKey=BackendPort,ParameterValue=4000 \
    --region us-east-1
```

**Wait for completion:**

```bash
aws cloudformation wait stack-create-complete --stack-name dev-todo-app-backend-service --region us-east-1
```

### Frontend Service

```bash
aws cloudformation create-stack \
    --stack-name dev-todo-app-frontend-service \
    --template-body file://cloudformation/ecs-service-frontend.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=AppName,ParameterValue=todo-app \
        ParameterKey=DesiredCount,ParameterValue=2 \
        ParameterKey=MinTasks,ParameterValue=1 \
        ParameterKey=MaxTasks,ParameterValue=4 \
        ParameterKey=TargetCPUUtilization,ParameterValue=70 \
        ParameterKey=FrontendPort,ParameterValue=3000 \
    --region us-east-1
```

**Wait for completion:**

```bash
aws cloudformation wait stack-create-complete --stack-name dev-todo-app-frontend-service --region us-east-1
```

---

## Verification

### Check ECS Services Status

```bash
# Backend Service
aws ecs describe-services \
    --cluster dev-todo-app-cluster \
    --services dev-todo-app-backend-service \
    --region us-east-1 \
    --query 'services[0].{status:status,runningCount:runningCount,desiredCount:desiredCount}' \
    --output table

# Frontend Service
aws ecs describe-services \
    --cluster dev-todo-app-cluster \
    --services dev-todo-app-frontend-service \
    --region us-east-1 \
    --query 'services[0].{status:status,runningCount:runningCount,desiredCount:desiredCount}' \
    --output table
```

### Check Task Health

```bash
# Backend Tasks
aws ecs describe-tasks \
    --cluster dev-todo-app-cluster \
    --tasks $(aws ecs list-tasks \
        --cluster dev-todo-app-cluster \
        --service-name dev-todo-app-backend-service \
        --region us-east-1 \
        --query 'taskArns' \
        --output text) \
    --region us-east-1 \
    --query 'tasks[*].{TaskArn:taskArn,Status:lastStatus,Health:healthStatus,DesiredStatus:desiredStatus}' \
    --output table

# Frontend Tasks
aws ecs describe-tasks \
    --cluster dev-todo-app-cluster \
    --tasks $(aws ecs list-tasks \
        --cluster dev-todo-app-cluster \
        --service-name dev-todo-app-frontend-service \
        --region us-east-1 \
        --query 'taskArns' \
        --output text) \
    --region us-east-1 \
    --query 'tasks[*].{TaskArn:taskArn,Status:lastStatus,Health:healthStatus,DesiredStatus:desiredStatus}' \
    --output table
```

### Check ALB Target Health

```bash
# Backend Target Group
BACKEND_TG_ARN=$(aws elbv2 describe-target-groups \
    --names dev-todo-app-backend-tg \
    --region us-east-1 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

aws elbv2 describe-target-health \
    --target-group-arn $BACKEND_TG_ARN \
    --region us-east-1 \
    --query 'TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth.State}' \
    --output table

# Frontend Target Group
FRONTEND_TG_ARN=$(aws elbv2 describe-target-groups \
    --names dev-todo-app-frontend-tg \
    --region us-east-1 \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

aws elbv2 describe-target-health \
    --target-group-arn $FRONTEND_TG_ARN \
    --region us-east-1 \
    --query 'TargetHealthDescriptions[*].{Target:Target.Id,Health:TargetHealth.State}' \
    --output table
```

### Access Your Application

```bash
ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name dev-todo-app-alb \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
    --output text)

echo "Application URL: http://${ALB_DNS}"
echo "Backend API: http://${ALB_DNS}/api/health"

# Test the backend
curl http://${ALB_DNS}/api/health

# Open the frontend in your browser
echo "Open in browser: http://${ALB_DNS}"
```

---

## Updating Stacks

### Push new changes to git

```bash
git status
git add .
git commit -m "v1.0.1"
git push origin main
git tag v1.0.1
git push --tags
```

### Build and Push New Version to ECR

```bash
export AWS_REGION="us-east-1"
export VERSION="v1.0.1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Build and push backend
echo "Building backend:${VERSION}..."
cd backend
docker buildx build --platform linux/amd64 -t todo-app-backend:${VERSION} .
docker tag todo-app-backend:${VERSION} ${ECR_REGISTRY}/todo-app:backend-${VERSION}
docker tag todo-app-backend:${VERSION} ${ECR_REGISTRY}/todo-app:backend-latest
cd ..

# Build and push frontend
echo "Building frontend:${VERSION}..."
cd frontend
docker buildx build --platform linux/amd64 -t todo-app-frontend:${VERSION} .
docker tag todo-app-frontend:${VERSION} ${ECR_REGISTRY}/todo-app:frontend-${VERSION}
docker tag todo-app-frontend:${VERSION} ${ECR_REGISTRY}/todo-app:frontend-latest
cd ..

echo "Authenticating to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

echo "Pushing to ECR..."
docker push ${ECR_REGISTRY}/todo-app:backend-${VERSION}
docker push ${ECR_REGISTRY}/todo-app:backend-latest
docker push ${ECR_REGISTRY}/todo-app:frontend-${VERSION}
docker push ${ECR_REGISTRY}/todo-app:frontend-latest

echo "✅ Successfully pushed all images"
```

### Force New Deployment (with latest tag)

If you pushed your new version with the `latest` tag, you can force a new deployment:

```bash
# Force new deployment for backend
aws ecs update-service \
    --cluster dev-todo-app-cluster \
    --service dev-todo-app-backend-service \
    --force-new-deployment \
    --region us-east-1

# Force new deployment for frontend
aws ecs update-service \
    --cluster dev-todo-app-cluster \
    --service dev-todo-app-frontend-service \
    --force-new-deployment \
    --region us-east-1
```

### Update Task Definition (with specific version)

For production deployments, it's better to update the task definition with a specific version:

```bash
# Update backend task definition
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_IMAGE_URI_BACKEND="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/todo-app:backend-v1.0.1"

aws cloudformation update-stack \
    --stack-name dev-todo-app-backend-task-definition \
    --template-body file://cloudformation/ecs-task-definition-backend.yaml \
    --parameters \
        ParameterKey=Environment,ParameterValue=dev \
        ParameterKey=AppName,ParameterValue=todo-app \
        ParameterKey=ECRImageURI,ParameterValue=${ECR_IMAGE_URI_BACKEND} \
        ParameterKey=BackendPort,ParameterValue=4000 \
        ParameterKey=TaskCPU,ParameterValue=256 \
        ParameterKey=TaskMemory,ParameterValue=512 \
    --capabilities CAPABILITY_NAMED_IAM \
    --region us-east-1

# Wait for update to complete
aws cloudformation wait stack-update-complete --stack-name dev-todo-app-backend-task-definition --region us-east-1

# Force new deployment to pick up the new task definition
aws ecs update-service \
    --cluster dev-todo-app-cluster \
    --service dev-todo-app-backend-service \
    --force-new-deployment \
    --region us-east-1
```

**Why specific versions are better for production:**

1. **Traceability**: Know exactly what code was running when
2. **Safe Rollback**: Instant rollback to previous versions
3. **Controlled Deployments**: You decide when to deploy
4. **Compliance & Auditing**: Required for SOC2, ISO 27001, etc.
5. **Blue-Green Deployments**: Test new versions before full rollout

---

## Cleanup (Delete All Stacks)

**⚠️ WARNING: This will delete all resources. Run in reverse order:**

```bash
# Step 1: Delete ECS Services
aws cloudformation delete-stack --stack-name dev-todo-app-frontend-service --region us-east-1
aws cloudformation delete-stack --stack-name dev-todo-app-backend-service --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name dev-todo-app-frontend-service --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name dev-todo-app-backend-service --region us-east-1

# Step 2: Delete Task Definitions
aws cloudformation delete-stack --stack-name dev-todo-app-frontend-task-definition --region us-east-1
aws cloudformation delete-stack --stack-name dev-todo-app-backend-task-definition --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name dev-todo-app-frontend-task-definition --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name dev-todo-app-backend-task-definition --region us-east-1

# Step 3: Delete ALB
aws cloudformation delete-stack --stack-name dev-todo-app-alb --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name dev-todo-app-alb --region us-east-1

# Step 4: Delete ECS Cluster
aws cloudformation delete-stack --stack-name dev-todo-app-ecs-cluster --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name dev-todo-app-ecs-cluster --region us-east-1

# Step 5: Delete Security Groups
aws cloudformation delete-stack --stack-name dev-todo-app-security-groups --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name dev-todo-app-security-groups --region us-east-1

# Step 6: Delete VPC
aws cloudformation delete-stack --stack-name dev-shared-vpc --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name dev-shared-vpc --region us-east-1

# Step 7: Delete ECR (optional - will delete all images)
aws cloudformation delete-stack --stack-name dev-todo-app-ecr --region us-east-1
aws cloudformation wait stack-delete-complete --stack-name dev-todo-app-ecr --region us-east-1
```

---

## Troubleshooting

### Check Stack Events for Errors

```bash
aws cloudformation describe-stack-events \
    --stack-name <stack-name> \
    --region us-east-1 \
    --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[ResourceType,ResourceStatusReason]' \
    --output table
```

### View ECS Service Events

```bash
# Backend Service
aws ecs describe-services \
    --cluster dev-todo-app-cluster \
    --services dev-todo-app-backend-service \
    --region us-east-1 \
    --query 'services[0].events[0:5]' \
    --output table

# Frontend Service
aws ecs describe-services \
    --cluster dev-todo-app-cluster \
    --services dev-todo-app-frontend-service \
    --region us-east-1 \
    --query 'services[0].events[0:5]' \
    --output table
```

### View CloudWatch Logs

```bash
# Backend logs
aws logs tail /ecs/dev-todo-app-backend --follow --region us-east-1

# Frontend logs
aws logs tail /ecs/dev-todo-app-frontend --follow --region us-east-1
```

### Check Task Stopped Reason

```bash
aws ecs describe-tasks \
    --cluster dev-todo-app-cluster \
    --tasks <task-id> \
    --region us-east-1 \
    --query 'tasks[0].stoppedReason'
```

### Common Issues

**Issue: Tasks keep stopping and restarting**
- Check CloudWatch logs for application errors
- Verify health check endpoints are responding correctly
- Ensure security groups allow traffic between ALB and ECS tasks

**Issue: ALB returning 503 Service Unavailable**
- Verify ECS tasks are running and healthy
- Check target group health in the ALB console
- Ensure health check path is correct and returning 200

**Issue: Cannot access the application**
- Verify ALB security group allows inbound traffic on port 80
- Check that ECS tasks are registered with the target groups
- Ensure NAT Gateway is functioning for private subnet internet access

---

## Environment Variables

For different environments (staging, prod), change the `Environment` parameter:

- **Development**: `ParameterKey=Environment,ParameterValue=dev`
- **Staging**: `ParameterKey=Environment,ParameterValue=staging`
- **Production**: `ParameterKey=Environment,ParameterValue=prod`

---

## Architecture Overview

```
Internet
    |
    v
Application Load Balancer (Public Subnets)
    |
    +-- Path: / --> Frontend Target Group --> Frontend ECS Tasks (Private Subnets)
    |
    +-- Path: /api/* --> Backend Target Group --> Backend ECS Tasks (Private Subnets)
```

**Key Components:**
- **VPC**: Isolated network with public and private subnets across 2 AZs
- **Public Subnets**: Host the Application Load Balancer
- **Private Subnets**: Host ECS Fargate tasks (backend and frontend)
- **NAT Gateway**: Allows private subnets to access internet for pulling images
- **Security Groups**: Control traffic between ALB and ECS tasks
- **Auto Scaling**: Automatically scales tasks based on CPU utilization

---

## Cost Optimization Tips

1. Use FARGATE_SPOT for non-production environments
2. Set appropriate auto-scaling limits (MinTasks, MaxTasks)
3. Enable ECR lifecycle policy to clean up old images
4. Use smaller task sizes (CPU/Memory) when possible
5. Delete unused stacks when not needed
6. Consider using a single NAT Gateway instead of one per AZ for dev environments

---

## Security Best Practices

1. ✅ Private subnets for ECS tasks
2. ✅ Security groups with minimal required access
3. ✅ ECR image scanning enabled
4. ✅ CloudWatch Container Insights for monitoring
5. ✅ IAM roles with least privilege
6. ✅ Encrypted ECR repositories
7. ⚠️ Consider adding HTTPS/SSL for ALB (requires ACM certificate)
8. ⚠️ Consider adding WAF for ALB protection
9. ⚠️ Consider adding DynamoDB for persistent storage

---

## Next Steps

1. **Add HTTPS/SSL**: Configure ACM certificate and update ALB for HTTPS
2. **Add Custom Domain**: Configure Route 53 for custom domain
3. **Add DynamoDB**: Create DynamoDB tables for multi-tenant data storage
4. **Add Authentication**: Implement user authentication and authorization
5. **Add CI/CD**: Set up automated deployments with CodePipeline or GitHub Actions
6. **Add Monitoring**: Set up CloudWatch alarms and dashboards
7. **Add Backup**: Configure automated backups for DynamoDB

---

For more information, refer to individual CloudFormation template files in the `cloudformation/` directory.

