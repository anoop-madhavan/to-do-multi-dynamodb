# CloudFormation Files Overview

This document provides a quick reference to all CloudFormation templates and scripts in this directory.

## CloudFormation Templates (*.yaml)

### Core Infrastructure

| File | Description | Resources Created |
|------|-------------|-------------------|
| `ecr-repository.yaml` | ECR repository for Docker images | ECR Repository with lifecycle policy, image scanning |
| `vpc-shared.yaml` | VPC and networking infrastructure | VPC, 2 Public Subnets, 2 Private Subnets, NAT Gateway, Internet Gateway, Route Tables |
| `security-groups.yaml` | Security groups for ALB and ECS | 3 Security Groups (ALB, Backend, Frontend) with ingress/egress rules |
| `ecs-cluster.yaml` | ECS cluster and logging | ECS Fargate Cluster, 2 CloudWatch Log Groups |
| `alb.yaml` | Application Load Balancer | ALB, 2 Target Groups, HTTP Listener, Path-based routing |

### Application Components

| File | Description | Resources Created |
|------|-------------|-------------------|
| `ecs-task-definition-backend.yaml` | Backend container configuration | Task Definition, IAM Execution Role, IAM Task Role |
| `ecs-task-definition-frontend.yaml` | Frontend container configuration | Task Definition, IAM Execution Role, IAM Task Role |
| `ecs-service-backend.yaml` | Backend service with auto-scaling | ECS Service, Auto-scaling Target, Scaling Policy |
| `ecs-service-frontend.yaml` | Frontend service with auto-scaling | ECS Service, Auto-scaling Target, Scaling Policy |

## Automation Scripts (*.sh)

### Deployment Scripts

| Script | Purpose | Usage | Time |
|--------|---------|-------|------|
| `build-and-push.sh` | Build Docker images and push to ECR | `./build-and-push.sh v1.0.0 us-east-1` | 3-5 min |
| `deploy-all.sh` | Deploy all CloudFormation stacks | `./deploy-all.sh dev us-east-1` | 10-12 min |
| `cleanup-all.sh` | Delete all CloudFormation stacks | `./cleanup-all.sh dev us-east-1` | 5-8 min |

### Script Details

#### `build-and-push.sh`
**What it does:**
1. Validates Docker is running
2. Checks if ECR repository exists
3. Authenticates with ECR
4. Builds backend Docker image (linux/amd64)
5. Builds frontend Docker image (linux/amd64)
6. Tags images with version and 'latest'
7. Pushes all images to ECR

**Output:**
- `${ECR_REGISTRY}/todo-app:backend-${VERSION}`
- `${ECR_REGISTRY}/todo-app:backend-latest`
- `${ECR_REGISTRY}/todo-app:frontend-${VERSION}`
- `${ECR_REGISTRY}/todo-app:frontend-latest`

#### `deploy-all.sh`
**What it does:**
1. Creates ECR repository
2. Creates VPC with subnets and NAT Gateway
3. Creates security groups
4. Creates ECS cluster
5. Creates Application Load Balancer
6. Creates task definitions (backend + frontend)
7. Creates ECS services (backend + frontend)
8. Displays application URL

**Prerequisites:**
- Docker images must exist in ECR (run `build-and-push.sh` first)

**Output:**
- 9 CloudFormation stacks
- Application accessible via ALB DNS

#### `cleanup-all.sh`
**What it does:**
1. Deletes ECS services (frontend + backend)
2. Deletes task definitions
3. Deletes Application Load Balancer
4. Deletes ECS cluster
5. Deletes security groups
6. Deletes VPC
7. Optionally deletes ECR repository

**Safety:**
- Requires typing "DELETE" to confirm
- Prompts before deleting ECR (which contains images)
- Deletes in reverse dependency order

## Documentation Files

| File | Description | Audience |
|------|-------------|----------|
| `README.md` | Overview of templates and architecture | DevOps, Developers |
| `FILES_OVERVIEW.md` | This file - quick reference | Everyone |
| `../DEPLOYMENT_GUIDE.md` | Complete deployment guide | Deployment engineers |
| `../QUICK_START.md` | Get started in 15 minutes | New users |

## Deployment Order

Stacks must be created in this order (handled automatically by `deploy-all.sh`):

```
1. ecr-repository.yaml
   ↓
2. vpc-shared.yaml
   ↓
3. security-groups.yaml
   ↓
4. ecs-cluster.yaml
   ↓
5. alb.yaml
   ↓
6. ecs-task-definition-backend.yaml
   ↓
7. ecs-task-definition-frontend.yaml
   ↓
8. ecs-service-backend.yaml
   ↓
9. ecs-service-frontend.yaml
```

## Stack Naming Convention

All stacks follow this naming pattern:
```
${Environment}-${AppName}-${Component}
${Environment}-shared-${Component}
```

**Examples:**
- `dev-todo-app-ecr`
- `dev-shared-vpc` (shared across apps)
- `dev-todo-app-backend-service`
- `dev-todo-app-frontend-task-definition`

## Parameters Reference

### Common Parameters

All templates accept these common parameters:

| Parameter | Values | Default | Description |
|-----------|--------|---------|-------------|
| `Environment` | dev, staging, prod | dev | Environment name |
| `AppName` | alphanumeric-hyphens | todo-app | Application name |
| `Region` | AWS region | us-east-1 | AWS region (in CLI commands) |

### Template-Specific Parameters

**ECR Repository:**
- `ImageTagMutability`: MUTABLE, IMMUTABLE
- `ScanOnPush`: enabled, disabled
- `MaxImageCount`: 1-100

**VPC:**
- `VpcCIDR`: IP CIDR (e.g., 10.0.0.0/16)
- `PublicSubnet1CIDR`, `PublicSubnet2CIDR`
- `PrivateSubnet1CIDR`, `PrivateSubnet2CIDR`

**Security Groups:**
- `BackendPort`: 1024-65535 (default: 4000)
- `FrontendPort`: 1024-65535 (default: 3000)

**ALB:**
- `BackendHealthCheckPath`: Path (default: /api/health)
- `FrontendHealthCheckPath`: Path (default: /)
- `HealthCheckInterval`: 5-300 seconds
- `HealthCheckTimeout`: 2-120 seconds

**Task Definitions:**
- `ECRImageURI`: Full ECR image URI
- `TaskCPU`: 256, 512, 1024, 2048, 4096
- `TaskMemory`: 512, 1024, 2048, 3072, 4096, etc.

**Services:**
- `DesiredCount`: 1-10 (desired tasks)
- `MinTasks`: Minimum tasks for auto-scaling
- `MaxTasks`: Maximum tasks for auto-scaling
- `TargetCPUUtilization`: 1-100 (percentage)

## Exports Reference

Templates use CloudFormation exports for cross-stack references:

### From VPC Stack
- `${Environment}-shared-vpc-id`
- `${Environment}-shared-public-subnet-1-id`
- `${Environment}-shared-public-subnet-2-id`
- `${Environment}-shared-private-subnet-1-id`
- `${Environment}-shared-private-subnet-2-id`

### From Security Groups Stack
- `${Environment}-${AppName}-alb-sg-id`
- `${Environment}-${AppName}-backend-sg-id`
- `${Environment}-${AppName}-frontend-sg-id`

### From ECS Cluster Stack
- `${Environment}-${AppName}-cluster-name`
- `${Environment}-${AppName}-backend-log-group-name`
- `${Environment}-${AppName}-frontend-log-group-name`

### From ALB Stack
- `${Environment}-${AppName}-alb-dns`
- `${Environment}-${AppName}-backend-tg-arn`
- `${Environment}-${AppName}-frontend-tg-arn`

### From Task Definition Stacks
- `${Environment}-${AppName}-backend-task-definition-arn`
- `${Environment}-${AppName}-frontend-task-definition-arn`

## Quick Commands Reference

### Deployment
```bash
# Full deployment (first time)
./build-and-push.sh v1.0.0 us-east-1
./deploy-all.sh dev us-east-1

# Update application
./build-and-push.sh v1.0.1 us-east-1
aws ecs update-service --cluster dev-todo-app-cluster \
    --service dev-todo-app-backend-service \
    --force-new-deployment --region us-east-1
```

### Monitoring
```bash
# View logs
aws logs tail /ecs/dev-todo-app-backend --follow --region us-east-1

# Check service status
aws ecs describe-services --cluster dev-todo-app-cluster \
    --services dev-todo-app-backend-service --region us-east-1

# List all stacks
aws cloudformation list-stacks --region us-east-1 \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query 'StackSummaries[?contains(StackName, `dev-todo-app`)].StackName'
```

### Cleanup
```bash
# Delete all resources
./cleanup-all.sh dev us-east-1

# Delete specific stack
aws cloudformation delete-stack --stack-name dev-todo-app-backend-service --region us-east-1
```

## File Sizes and Counts

**Templates:** 9 YAML files (~8-12 KB each)
**Scripts:** 3 Bash scripts (~5-10 KB each)
**Documentation:** 4 Markdown files

**Total:** 16 files, ~150 KB

## Version History

- **v1.0.0** - Initial release with complete ECS Fargate deployment
  - ECR repository with lifecycle policy
  - VPC with public/private subnets
  - Application Load Balancer with path-based routing
  - Backend and Frontend services with auto-scaling
  - Automated deployment and cleanup scripts

## Support

For issues or questions:
1. Check [DEPLOYMENT_GUIDE.md](../DEPLOYMENT_GUIDE.md) for detailed instructions
2. Check [QUICK_START.md](../QUICK_START.md) for quick reference
3. Review CloudFormation events in AWS Console
4. Check CloudWatch logs for application errors

## License

See the main repository LICENSE file.

