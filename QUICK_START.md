# Quick Start Guide - Deploy Todo App to AWS

This guide will help you deploy the Todo App to AWS in under 15 minutes.

## Prerequisites

Before you begin, ensure you have:

- ✅ AWS CLI installed and configured
- ✅ Docker installed and running
- ✅ AWS credentials with appropriate permissions
- ✅ Git for version control (optional)

## Quick Deployment Steps

### 1. Clone or Navigate to Project

```bash
cd /path/to/to-do-multi-dynamodb
```

### 2. Deploy Infrastructure (10-12 minutes)

Navigate to the cloudformation directory and run the deployment script:

```bash
cd cloudformation
./deploy-all.sh dev us-east-1
```

This script will:
- ✅ Create ECR repository
- ✅ Create VPC with public/private subnets
- ✅ Create security groups
- ✅ Create ECS cluster
- ✅ Create Application Load Balancer
- ✅ Create task definitions
- ✅ Create ECS services with auto-scaling

**Note**: The script will check if Docker images exist in ECR. If not, follow step 3 first.

### 3. Build and Push Docker Images (3-5 minutes)

If you need to build and push images:

```bash
./build-and-push.sh v1.0.0 us-east-1
```

This will:
- ✅ Build backend Docker image
- ✅ Build frontend Docker image
- ✅ Push both images to ECR with version tag and 'latest' tag

### 4. Wait for Services to Start (2-3 minutes)

Wait for ECS tasks to start and become healthy:

```bash
# Check backend service
aws ecs describe-services \
    --cluster dev-todo-app-cluster \
    --services dev-todo-app-backend-service \
    --region us-east-1 \
    --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'

# Check frontend service
aws ecs describe-services \
    --cluster dev-todo-app-cluster \
    --services dev-todo-app-frontend-service \
    --region us-east-1 \
    --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'
```

### 5. Get Application URL

```bash
ALB_DNS=$(aws cloudformation describe-stacks \
    --stack-name dev-todo-app-alb \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
    --output text)

echo "Application URL: http://${ALB_DNS}"
echo "Backend API: http://${ALB_DNS}/api/health"
```

### 6. Test Your Application

```bash
# Test backend health endpoint
curl http://${ALB_DNS}/api/health

# Open frontend in browser
open http://${ALB_DNS}  # macOS
# or
xdg-open http://${ALB_DNS}  # Linux
```

---

## All-in-One Deployment Script

If you already have Docker images ready, use this single command:

```bash
cd cloudformation

# First time deployment
./build-and-push.sh v1.0.0 us-east-1 && ./deploy-all.sh dev us-east-1
```

---

## Development Workflow

### Update Application Code

When you make changes to your application:

```bash
# 1. Commit your changes
git add .
git commit -m "Update feature X"
git tag v1.0.1
git push origin main --tags

# 2. Build and push new version
cd cloudformation
./build-and-push.sh v1.0.1 us-east-1

# 3. Force new deployment (using latest tag)
aws ecs update-service \
    --cluster dev-todo-app-cluster \
    --service dev-todo-app-backend-service \
    --force-new-deployment \
    --region us-east-1

aws ecs update-service \
    --cluster dev-todo-app-cluster \
    --service dev-todo-app-frontend-service \
    --force-new-deployment \
    --region us-east-1

# 4. Monitor deployment
aws ecs describe-services \
    --cluster dev-todo-app-cluster \
    --services dev-todo-app-backend-service dev-todo-app-frontend-service \
    --region us-east-1 \
    --query 'services[*].{name:serviceName,running:runningCount,desired:desiredCount}'
```

---

## Monitoring and Troubleshooting

### View Logs

```bash
# Backend logs
aws logs tail /ecs/dev-todo-app-backend --follow --region us-east-1

# Frontend logs
aws logs tail /ecs/dev-todo-app-frontend --follow --region us-east-1
```

### Check Service Health

```bash
# Service status
aws ecs describe-services \
    --cluster dev-todo-app-cluster \
    --services dev-todo-app-backend-service dev-todo-app-frontend-service \
    --region us-east-1

# Task status
aws ecs list-tasks \
    --cluster dev-todo-app-cluster \
    --service-name dev-todo-app-backend-service \
    --region us-east-1
```

### Check ALB Target Health

```bash
# Backend target group
aws elbv2 describe-target-health \
    --target-group-arn $(aws elbv2 describe-target-groups \
        --names dev-todo-app-backend-tg \
        --region us-east-1 \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text) \
    --region us-east-1

# Frontend target group
aws elbv2 describe-target-health \
    --target-group-arn $(aws elbv2 describe-target-groups \
        --names dev-todo-app-frontend-tg \
        --region us-east-1 \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text) \
    --region us-east-1
```

---

## Cleanup

When you're done testing, delete all resources:

```bash
cd cloudformation
./cleanup-all.sh dev us-east-1
```

This will delete all CloudFormation stacks in reverse order. You'll be prompted to confirm before deletion.

---

## Cost Estimate

**Development Environment (Running 24/7):**
- NAT Gateway: ~$32/month
- ECS Fargate (4 tasks): ~$60/month
- ALB: ~$16/month
- ECR Storage: ~$1/month (for ~10GB)
- CloudWatch Logs: ~$1/month (first 5GB free)
- **Total**: ~$110/month

**Cost Savings Tips:**
1. **Delete when not in use**: Run `./cleanup-all.sh` at end of day
2. **Reduce task count**: Set `DesiredCount=1` for dev environment
3. **Use Fargate Spot**: Save up to 70% on compute costs
4. **Stop services after hours**: Use EventBridge to stop/start services

---

## What's Deployed?

Your infrastructure includes:

```
┌─────────────────────────────────────────────────────────────┐
│ Region: us-east-1                                            │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ VPC (10.0.0.0/16)                                  │    │
│  │                                                     │    │
│  │  Public Subnets (2 AZs)                            │    │
│  │  ├─ ALB (Internet-facing)                          │    │
│  │  └─ NAT Gateway                                    │    │
│  │                                                     │    │
│  │  Private Subnets (2 AZs)                           │    │
│  │  ├─ Backend ECS Tasks (Port 4000)                  │    │
│  │  └─ Frontend ECS Tasks (Port 3000)                 │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ECS Cluster: dev-todo-app-cluster                  │    │
│  │  ├─ Backend Service (Auto-scaling: 1-4 tasks)      │    │
│  │  └─ Frontend Service (Auto-scaling: 1-4 tasks)     │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ECR Repository: todo-app                           │    │
│  │  ├─ backend-latest, backend-v1.0.0                 │    │
│  │  └─ frontend-latest, frontend-v1.0.0               │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ CloudWatch Logs                                     │    │
│  │  ├─ /ecs/dev-todo-app-backend                      │    │
│  │  └─ /ecs/dev-todo-app-frontend                     │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| `build-and-push.sh` | Build and push Docker images | `./build-and-push.sh v1.0.0 us-east-1` |
| `deploy-all.sh` | Deploy all CloudFormation stacks | `./deploy-all.sh dev us-east-1` |
| `cleanup-all.sh` | Delete all resources | `./cleanup-all.sh dev us-east-1` |

---

## Next Steps

After successful deployment:

1. **Add Custom Domain** - Configure Route 53 and add HTTPS
2. **Add DynamoDB** - Implement multi-tenant data storage
3. **Add Authentication** - Integrate Cognito or Auth0
4. **Add Monitoring** - Set up CloudWatch dashboards and alarms
5. **Add CI/CD** - Automate deployments with GitHub Actions or CodePipeline
6. **Add Backups** - Configure automated backups for data

---

## Troubleshooting

### Issue: "Stack already exists"
**Solution**: Stack was created previously. Either delete it first or skip that step.

### Issue: "Docker images not found in ECR"
**Solution**: Run `./build-and-push.sh` first to build and push images.

### Issue: "Tasks keep stopping"
**Solution**: Check CloudWatch logs for application errors.

### Issue: "503 Service Unavailable"
**Solution**: Wait for tasks to become healthy. Check target group health.

### Issue: "Permission denied on scripts"
**Solution**: Run `chmod +x *.sh` in the cloudformation directory.

---

## Support

For detailed information:
- **Full Deployment Guide**: See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **CloudFormation Templates**: See [cloudformation/README.md](cloudformation/README.md)
- **AWS Documentation**: https://docs.aws.amazon.com/

---

## Summary

You should now have:
- ✅ Todo App running on AWS ECS Fargate
- ✅ Application Load Balancer routing traffic
- ✅ Auto-scaling based on CPU utilization
- ✅ CloudWatch logs for monitoring
- ✅ Secure networking with private subnets

**Access your app**: http://[YOUR-ALB-DNS]

Happy coding! 🚀

