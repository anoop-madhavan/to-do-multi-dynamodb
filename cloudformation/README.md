# CloudFormation Templates for Todo App

This directory contains AWS CloudFormation templates for deploying the Todo App infrastructure.

## Templates Overview

### 1. ECR Repository (`ecr-repository.yaml`)
Creates an Amazon ECR repository for storing Docker images.
- Image scanning on push
- Lifecycle policy to manage image retention
- Encryption enabled

### 2. VPC and Networking (`vpc-shared.yaml`)
Creates a shared VPC with:
- 2 Public subnets (across 2 AZs)
- 2 Private subnets (across 2 AZs)
- Internet Gateway for public subnets
- NAT Gateway for private subnets
- Route tables and associations

### 3. Security Groups (`security-groups.yaml`)
Creates security groups for:
- Application Load Balancer (allows HTTP/HTTPS from internet)
- Backend ECS tasks (allows traffic from ALB on port 4000)
- Frontend ECS tasks (allows traffic from ALB on port 3000)

### 4. ECS Cluster (`ecs-cluster.yaml`)
Creates:
- ECS Fargate cluster
- CloudWatch Log Groups for backend and frontend
- Container Insights enabled

### 5. Application Load Balancer (`alb.yaml`)
Creates:
- Application Load Balancer in public subnets
- Backend Target Group (for /api/* routes)
- Frontend Target Group (for / routes)
- HTTP Listener with path-based routing

### 6. ECS Task Definitions
- **Backend** (`ecs-task-definition-backend.yaml`): Container configuration for backend API
- **Frontend** (`ecs-task-definition-frontend.yaml`): Container configuration for frontend UI

Both include:
- IAM roles for task execution and application
- CloudWatch logging configuration
- Health checks
- Environment variables

### 7. ECS Services
- **Backend** (`ecs-service-backend.yaml`): ECS service for backend with auto-scaling
- **Frontend** (`ecs-service-frontend.yaml`): ECS service for frontend with auto-scaling

Both include:
- Auto-scaling based on CPU utilization
- Deployment circuit breaker for automatic rollback
- Health check grace period
- Integration with ALB target groups

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Application Load Balancer                       │
│                     (Public Subnets)                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Listener Rule: /         → Frontend Target Group        │  │
│  │  Listener Rule: /api/*    → Backend Target Group         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────┬────────────────────┬───────────────────────┘
                      │                    │
        ┌─────────────▼──────┐   ┌────────▼───────────┐
        │  Frontend Target   │   │  Backend Target    │
        │      Group         │   │      Group         │
        └─────────────┬──────┘   └────────┬───────────┘
                      │                    │
        ┌─────────────▼──────────────────────▼───────────┐
        │           Private Subnets (2 AZs)              │
        │  ┌──────────────────┐  ┌──────────────────┐   │
        │  │ Frontend Tasks   │  │  Backend Tasks   │   │
        │  │   (Fargate)      │  │   (Fargate)      │   │
        │  └──────────────────┘  └──────────────────┘   │
        └─────────────────────────────────────────────────┘
                              │
                              ▼
                        NAT Gateway
                              │
                              ▼
                          Internet
                    (for pulling images)
```

## Deployment Order

Templates must be deployed in this order due to dependencies:

1. **ecr-repository.yaml** - Create ECR first to push images
2. **vpc-shared.yaml** - Foundation networking infrastructure
3. **security-groups.yaml** - Network security (depends on VPC)
4. **ecs-cluster.yaml** - ECS cluster and log groups
5. **alb.yaml** - Load balancer and target groups (depends on VPC and security groups)
6. **ecs-task-definition-backend.yaml** - Backend task definition (depends on ECR, cluster)
7. **ecs-task-definition-frontend.yaml** - Frontend task definition (depends on ECR, cluster)
8. **ecs-service-backend.yaml** - Backend service (depends on task definition, ALB)
9. **ecs-service-frontend.yaml** - Frontend service (depends on task definition, ALB)

## Parameters

All templates use consistent parameters:

- **Environment**: `dev`, `staging`, or `prod`
- **AppName**: `todo-app` (default)
- **Region**: `us-east-1` (specified in deployment commands)

## Stack Naming Convention

All stacks follow this naming pattern:
```
${Environment}-${AppName}-${Resource}
```

Examples:
- `dev-todo-app-ecr`
- `dev-todo-app-backend-service`
- `dev-shared-vpc` (shared across applications)

## Exports

Templates use CloudFormation exports for cross-stack references:

**From VPC stack:**
- `${Environment}-shared-vpc-id`
- `${Environment}-shared-public-subnet-1-id`
- `${Environment}-shared-public-subnet-2-id`
- `${Environment}-shared-private-subnet-1-id`
- `${Environment}-shared-private-subnet-2-id`

**From Security Groups stack:**
- `${Environment}-${AppName}-alb-sg-id`
- `${Environment}-${AppName}-backend-sg-id`
- `${Environment}-${AppName}-frontend-sg-id`

**From ECS Cluster stack:**
- `${Environment}-${AppName}-cluster-name`
- `${Environment}-${AppName}-backend-log-group-name`
- `${Environment}-${AppName}-frontend-log-group-name`

**From ALB stack:**
- `${Environment}-${AppName}-alb-dns`
- `${Environment}-${AppName}-backend-tg-arn`
- `${Environment}-${AppName}-frontend-tg-arn`

**From Task Definition stacks:**
- `${Environment}-${AppName}-backend-task-definition-arn`
- `${Environment}-${AppName}-frontend-task-definition-arn`

## Usage

See the main [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) in the root directory for detailed deployment instructions.

Quick deployment:

```bash
cd cloudformation

# Deploy all stacks (in order)
./deploy-all.sh dev us-east-1

# Deploy individual stack
aws cloudformation create-stack \
    --stack-name dev-todo-app-ecr \
    --template-body file://ecr-repository.yaml \
    --parameters ParameterKey=Environment,ParameterValue=dev \
                 ParameterKey=AppName,ParameterValue=todo-app \
    --region us-east-1
```

## Resource Costs (Approximate)

**Development Environment (us-east-1):**
- VPC: Free (NAT Gateway: ~$32/month)
- ECS Fargate: ~$15/month per task (2 backend + 2 frontend = ~$60/month)
- ALB: ~$16/month + data processing charges
- ECR: First 50GB free, then $0.10/GB/month
- CloudWatch Logs: First 5GB free, then $0.50/GB
- **Total Estimated**: ~$110-130/month for dev environment

**Production Environment:**
- Scale up tasks and enable backups
- Add HTTPS certificate (free with ACM)
- Add DynamoDB (pay per request or provisioned capacity)
- Add CloudWatch alarms and dashboards
- **Total Estimated**: $200-500/month depending on traffic

## Cost Optimization

1. **Use Fargate Spot** for non-production:
   - Up to 70% cost savings
   - Modify `ecs-cluster.yaml` to use FARGATE_SPOT by default

2. **Reduce task count** in dev:
   - Set `MinTasks=1` and `DesiredCount=1` for dev environment

3. **Delete dev stacks** when not in use:
   - Run cleanup script to delete all resources

4. **Use lifecycle policies**:
   - ECR lifecycle policy already configured to keep only 10 images

## Security Considerations

1. **Private Subnets**: ECS tasks run in private subnets with no direct internet access
2. **Security Groups**: Restrictive rules, only ALB can reach ECS tasks
3. **IAM Roles**: Least privilege access for ECS tasks
4. **ECR Scanning**: Automatic vulnerability scanning enabled
5. **Encryption**: ECR repositories encrypted with AES256

**Recommendations for Production:**
- Enable HTTPS with ACM certificate
- Add WAF rules to ALB
- Enable GuardDuty for threat detection
- Add Secrets Manager for sensitive data
- Enable VPC Flow Logs
- Add backup strategy for data

## Troubleshooting

**Common Issues:**

1. **Stack creation fails with "Export already exists"**
   - Another stack with same environment name exists
   - Delete the old stack or use a different environment name

2. **ECS tasks fail to start**
   - Check CloudWatch logs for application errors
   - Verify ECR image URI is correct
   - Ensure IAM roles have correct permissions

3. **ALB health checks failing**
   - Verify health check paths are correct
   - Check security groups allow traffic
   - Review application logs in CloudWatch

4. **Can't delete VPC stack**
   - Ensure all dependent stacks are deleted first
   - Check for manually created resources in VPC
   - Delete ENIs created by ECS tasks

## Support

For issues or questions:
1. Check CloudWatch Logs for application errors
2. Review CloudFormation events for stack errors
3. Check AWS documentation for service limits
4. Review the main [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md)

## License

See the main repository LICENSE file.

