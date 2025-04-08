# Keep AIOps Platform AWS Deployment Guide

## Overview

This guide details how to deploy the Keep AIOps platform on Amazon Web Services (AWS). The architecture leverages AWS managed services to provide a scalable, secure, and highly available deployment of Keep for production environments.

## Architecture

The Keep platform on AWS uses a containerized approach with Amazon EKS (Elastic Kubernetes Service) as the primary compute platform. Supporting services like databases, caching, and monitoring are implemented using AWS managed services to reduce operational overhead.

### Core Components

1. **Amazon EKS (Elastic Kubernetes Service)**
   - Managed Kubernetes service for container orchestration
   - Hosts the Keep API, UI, WebSocket server, and worker pods
   - Provides auto-scaling, self-healing, and rolling updates

2. **Amazon RDS (Relational Database Service)**
   - Managed PostgreSQL database for persistent storage
   - Stores alerts, incidents, workflows, and configuration data
   - Offers automated backups, point-in-time recovery, and read replicas

3. **Amazon ElastiCache for Redis**
   - Managed Redis for caching and task queuing
   - Provides in-memory data storage for fast access
   - Supports background task processing via ARQ

4. **AWS Secrets Manager**
   - Secure storage for provider credentials and secrets
   - Integration with IAM for access control
   - Automatic rotation of sensitive credentials

5. **Amazon CloudWatch**
   - Centralized logging and monitoring
   - Collection of performance metrics
   - Alerting on infrastructure and application issues

6. **Amazon Cognito**
   - User authentication and authorization
   - Integration with existing identity providers (optional)
   - Multi-factor authentication support

7. **AWS WAF (Web Application Firewall)**
   - Protection against common web exploits
   - Rate limiting and bot control
   - Geographic restrictions if required

8. **Amazon Route 53**
   - DNS management for the Keep platform
   - Health checking and failover routing
   - Integration with AWS Certificate Manager for SSL/TLS

9. **Application Load Balancer (ALB)**
   - Distributes traffic to Keep services
   - Supports WebSocket connections
   - SSL/TLS termination

## Deployment Architecture

The deployment architecture follows AWS best practices for security, scalability, and high availability:

### Networking

- All components are deployed within a dedicated VPC (Virtual Private Cloud)
- Multiple Availability Zones for high availability
- Public and private subnets with appropriate routing
- Security groups to control traffic between components
- Network ACLs for additional security

### Compute Layer

Keep components are deployed as containerized applications on Amazon EKS:

1. **Keep UI**
   - Stateless NextJS application
   - Horizontally scalable based on CPU/memory usage
   - Configured with auto-scaling policies

2. **Keep API**
   - FastAPI application running on Kubernetes
   - Horizontally scalable based on request volume
   - Automatic health checks and self-healing

3. **WebSocket Server**
   - Soketi server for real-time updates
   - Sticky sessions through the load balancer
   - Scales based on connection count

4. **Background Workers**
   - ARQ workers for asynchronous processing
   - Dedicated processing for workflows and tasks
   - Horizontally scalable based on queue depth

### Data Layer

The data layer uses AWS managed services for persistence and caching:

1. **PostgreSQL on RDS**
   - Multi-AZ deployment for high availability
   - Automated backups and maintenance
   - Monitoring and performance insights

2. **Redis on ElastiCache**
   - Cluster mode for distributed caching
   - In-memory storage for performance
   - Replication across availability zones

### Security Layer

The security architecture includes multiple protective measures:

1. **AWS WAF**
   - Protection against OWASP Top 10 vulnerabilities
   - Rate limiting to prevent DDoS attacks
   - Custom rules for application-specific protection

2. **Cognito Authentication**
   - Secure user management
   - Integration with existing identity providers
   - Role-based access control

3. **Secrets Management**
   - Secure storage for provider credentials
   - Environment-specific secrets
   - Integration with IAM roles for EKS

4. **Network Security**
   - Isolation through VPC
   - Security groups for fine-grained control
   - Private subnets for database and cache instances

## Implementation Guide

### Prerequisites

1. AWS Account with appropriate permissions
2. AWS CLI configured with administrator access
3. `kubectl` and `eksctl` command-line tools
4. Helm package manager
5. Docker for building container images

### Step 1: Network Setup

Create the VPC and networking components:

```bash
# Create VPC with private and public subnets across 3 AZs
aws cloudformation create-stack \
  --stack-name keep-vpc \
  --template-url https://s3.amazonaws.com/cloudformation-templates-us-east-1/vpc/vpc-3azs.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=keep-production
```

### Step 2: Database Setup

Create the PostgreSQL database on RDS:

```bash
# Create RDS PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier keep-db \
  --db-instance-class db.t3.medium \
  --engine postgres \
  --master-username keep_admin \
  --master-user-password <secure-password> \
  --allocated-storage 100 \
  --backup-retention-period 7 \
  --multi-az \
  --db-subnet-group-name keep-db-subnet-group \
  --vpc-security-group-ids <security-group-id>
```

### Step 3: Redis Cache Setup

Create ElastiCache for Redis:

```bash
# Create ElastiCache Redis cluster
aws elasticache create-cache-cluster \
  --cache-cluster-id keep-redis \
  --engine redis \
  --cache-node-type cache.t3.medium \
  --num-cache-nodes 1 \
  --security-group-ids <security-group-id> \
  --cache-subnet-group-name keep-cache-subnet-group
```

### Step 4: EKS Cluster Creation

Create the EKS cluster for running Keep services:

```bash
# Create EKS cluster
eksctl create cluster \
  --name keep-cluster \
  --version 1.24 \
  --region us-east-1 \
  --nodegroup-name standard-nodes \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 5 \
  --with-oidc \
  --vpc-private-subnets <private-subnet-list> \
  --vpc-public-subnets <public-subnet-list>
```

### Step 5: Secrets Manager Setup

Create secrets for the Keep platform:

```bash
# Create secrets for database access
aws secretsmanager create-secret \
  --name keep/production/db \
  --description "Keep database credentials" \
  --secret-string '{"username":"keep_admin","password":"<secure-password>","host":"<db-endpoint>","port":"5432","dbname":"keep"}'

# Create secrets for provider credentials
aws secretsmanager create-secret \
  --name keep/production/providers \
  --description "Keep provider credentials" \
  --secret-string '{"slack":{"token":"xoxb-..."},"jira":{"api_key":"..."}}'
```

### Step 6: Load Balancer and DNS Setup

Create an Application Load Balancer and DNS entries:

```bash
# Create Application Load Balancer (using CloudFormation or AWS Console)

# Create DNS entries in Route 53
aws route53 change-resource-record-sets \
  --hosted-zone-id <hosted-zone-id> \
  --change-batch '{
    "Changes": [
      {
        "Action": "CREATE",
        "ResourceRecordSet": {
          "Name": "keep.example.com",
          "Type": "A",
          "AliasTarget": {
            "HostedZoneId": "<load-balancer-hosted-zone-id>",
            "DNSName": "<load-balancer-dns-name>",
            "EvaluateTargetHealth": true
          }
        }
      }
    ]
  }'
```

### Step 7: Deploy Keep Components

Deploy Keep components to EKS using Helm charts:

```bash
# Add Keep Helm repository
helm repo add keep https://charts.keephq.dev

# Install Keep components
helm install keep keep/keep \
  --namespace keep \
  --create-namespace \
  --set database.host=<rds-endpoint> \
  --set database.name=keep \
  --set database.secretName=keep/production/db \
  --set redis.host=<elasticache-endpoint> \
  --set secretsManager.enabled=true \
  --set secretsManager.type=aws \
  --set ingress.enabled=true \
  --set ingress.annotations."kubernetes\.io/ingress\.class"=alb \
  --set ingress.hosts[0].host=keep.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

### Step 8: Configure Authentication

Configure Amazon Cognito for user authentication:

```bash
# Create Cognito User Pool
aws cognito-idp create-user-pool \
  --pool-name keep-users \
  --auto-verify-attributes email \
  --schema '[{"Name":"email","Required":true}]' \
  --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":true,"RequireLowercase":true,"RequireNumbers":true,"RequireSymbols":true}}' \
  --username-attributes email

# Create Cognito App Client
aws cognito-idp create-user-pool-client \
  --user-pool-id <user-pool-id> \
  --client-name keep-app \
  --no-generate-secret \
  --allowed-o-auth-flows-user-pool-client \
  --allowed-o-auth-flows code \
  --allowed-o-auth-scopes "openid" "email" "profile" \
  --callback-urls '["https://keep.example.com/auth/callback"]' \
  --logout-urls '["https://keep.example.com/"]' \
  --supported-identity-providers COGNITO
```

### Step 9: Configure Monitoring

Set up CloudWatch for monitoring and logging:

```bash
# Deploy CloudWatch agent to EKS (using Helm)
helm install cloudwatch-agent amazon/cloudwatch-agent \
  --namespace amazon-cloudwatch \
  --create-namespace \
  --set clusterName=keep-cluster

# Set up CloudWatch alarms for critical components
aws cloudwatch put-metric-alarm \
  --alarm-name keep-api-high-cpu \
  --alarm-description "Alarm when API CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EKS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ClusterName,Value=keep-cluster Name=Namespace,Value=keep \
  --evaluation-periods 2 \
  --alarm-actions <sns-topic-arn>
```

### Step 10: Security Configuration

Configure AWS WAF for application protection:

```bash
# Create AWS WAF Web ACL
aws wafv2 create-web-acl \
  --name keep-waf \
  --scope REGIONAL \
  --default-action Allow={} \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=keep-waf \
  --rules '[{...OWASP Top 10 rule configurations...}]' \
  --region us-east-1

# Associate WAF with the Application Load Balancer
aws wafv2 associate-web-acl \
  --web-acl-arn <web-acl-arn> \
  --resource-arn <alb-arn> \
  --region us-east-1
```

## Production Considerations

### High Availability

1. **Multi-AZ Deployment**
   - EKS nodes spread across multiple Availability Zones
   - RDS configured for Multi-AZ operation
   - ElastiCache with replicas in different AZs

2. **Auto-Scaling**
   - Horizontal pod autoscaling for Keep components
   - Node autoscaling for EKS cluster
   - Read replicas for database scaling

### Disaster Recovery

1. **Automated Backups**
   - RDS daily automated backups
   - S3 bucket for configuration backups
   - Infrastructure as code for quick reconstruction

2. **Recovery Procedures**
   - Point-in-time recovery for RDS
   - Multi-region backup copies
   - Regular recovery testing

### Security

1. **Network Security**
   - Public services behind WAF
   - Internal services in private subnets
   - Security groups limiting access

2. **Data Security**
   - Encryption at rest for RDS and ElastiCache
   - Encryption in transit with TLS
   - IAM roles for service-to-service communication

3. **Compliance**
   - VPC Flow Logs for network auditing
   - CloudTrail for API auditing
   - AWS Config for compliance monitoring

### Maintenance

1. **Zero-Downtime Updates**
   - Rolling updates for Kubernetes deployments
   - Blue-green deployments for major version changes
   - Database maintenance windows during off-hours

2. **Monitoring and Alerting**
   - CloudWatch dashboards for key metrics
   - Alarms for critical thresholds
   - Log aggregation and analysis

## Cost Optimization

1. **Right-Sizing**
   - Select appropriate instance types based on workload
   - Use Spot Instances for background workers
   - Auto-scaling based on demand

2. **Storage Optimization**
   - S3 Intelligent Tiering for backups
   - RDS storage auto-scaling
   - Regular cleanup of obsolete data

3. **Reserved Instances**
   - Purchase Reserved Instances for stable components
   - Savings Plans for compute savings
   - Regular cost analysis and optimization

## Integration with AWS Services

### AWS-Specific Providers

Keep can integrate with various AWS services through its provider system:

1. **Amazon CloudWatch** 
   - Receive alerts from CloudWatch Alarms
   - Query CloudWatch Metrics for enrichment
   - Access CloudWatch Logs for context

2. **AWS EventBridge**
   - Receive events from AWS services
   - Trigger workflows based on infrastructure events
   - Integrate with AWS service health events

3. **AWS Systems Manager**
   - Execute remediation scripts 
   - Manage EC2 instances during incidents
   - Access parameter store for configuration

4. **AWS Lambda**
   - Custom integrations via Lambda functions
   - Serverless remediation actions
   - Event processing and transformation

## Advanced Configurations

### Implementing Custom Providers for AWS Services

Create custom providers to integrate with AWS services not covered by built-in providers:

```python
# Example of a custom AWS provider
from keep.providers.base import BaseProvider, provider_method

class AWSCustomProvider(BaseProvider):
    provider_type = "aws_custom"
    
    @provider_method
    def restart_ec2_instance(self, instance_id: str) -> dict:
        """
        Restart an EC2 instance.
        """
        import boto3
        ec2 = boto3.client('ec2')
        response = ec2.reboot_instances(InstanceIds=[instance_id])
        return {"success": True, "response": response}
```

### AWS-Specific Workflow Examples

Example of a workflow that handles EC2 instance high CPU alerts:

```yaml
name: EC2 High CPU Response
description: Automated response to EC2 high CPU alerts
triggers:
  - type: alert
    filters:
      provider: cloudwatch
      metric: CPUUtilization
      namespace: AWS/EC2
      threshold: 90
steps:
  get_instance_details:
    name: Get EC2 Instance Details
    action: aws.describe_instance
    params:
      instance_id: "{{ context.alert.dimensions.InstanceId }}"
  
  check_auto_scaling:
    name: Check if Instance is in Auto Scaling Group
    action: aws.describe_auto_scaling_instances
    params:
      instance_ids: ["{{ context.alert.dimensions.InstanceId }}"]
  
  notify_team:
    name: Notify DevOps Team
    action: slack.post_message
    params:
      channel: "#aws-alerts"
      message: |
        High CPU Alert for EC2 Instance: {{ context.alert.dimensions.InstanceId }}
        Instance Type: {{ context.get_instance_details.result.InstanceType }}
        In Auto Scaling Group: {{ context.check_auto_scaling.result.AutoScalingInstances | length > 0 }}
        
  collect_metrics:
    name: Collect Additional Metrics
    action: cloudwatch.get_metric_data
    params:
      metrics:
        - namespace: AWS/EC2
          metric_name: NetworkIn
          dimensions:
            - name: InstanceId
              value: "{{ context.alert.dimensions.InstanceId }}"
        - namespace: AWS/EC2
          metric_name: NetworkOut
          dimensions:
            - name: InstanceId
              value: "{{ context.alert.dimensions.InstanceId }}"
      start_time: "{{ context.alert.timestamp - 3600 }}"
      end_time: "{{ context.alert.timestamp }}"
      period: 300
  
  investigate_with_ai:
    name: AI Analysis of Instance Metrics
    depends_on: [collect_metrics, get_instance_details]
    action: openai.chat
    params:
      model: gpt-4
      messages:
        - role: system
          content: "You are an AWS performance expert. Analyze these EC2 metrics and suggest possible causes for high CPU."
        - role: user
          content: |
            Instance Type: {{ context.get_instance_details.result.InstanceType }}
            High CPU Alert: {{ context.alert.value }}%
            NetworkIn: {{ context.collect_metrics.result.MetricDataResults[0].Values }}
            NetworkOut: {{ context.collect_metrics.result.MetricDataResults[1].Values }}
  
  create_ticket:
    name: Create Jira Ticket
    depends_on: investigate_with_ai
    action: jira.create_issue
    params:
      project: INFRA
      summary: "High CPU on EC2 Instance {{ context.alert.dimensions.InstanceId }}"
      description: |
        EC2 Instance {{ context.alert.dimensions.InstanceId }} is experiencing high CPU usage.
        
        ## Instance Details
        - Instance Type: {{ context.get_instance_details.result.InstanceType }}
        - Launch Time: {{ context.get_instance_details.result.LaunchTime }}
        - State: {{ context.get_instance_details.result.State.Name }}
        
        ## AI Analysis
        {{ context.investigate_with_ai.result.choices[0].message.content }}
```

## Conclusion

Deploying Keep on AWS provides a scalable, secure, and reliable platform for AIOps and incident management. By leveraging AWS managed services, you can reduce operational overhead while maintaining high availability and security. The flexibility of Keep's architecture allows it to integrate seamlessly with AWS services, providing enhanced value through automation and intelligent incident management.

The deployment architecture outlined in this guide follows AWS best practices and provides a solid foundation for running Keep in production environments. By following the implementation steps and considering the production recommendations, you can create a robust AIOps platform that meets your organization's incident management needs. 