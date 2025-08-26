# CI/CD Setup Guide

This guide explains how to set up automated CI/CD for Azure API Management (APIM) infrastructure and API deployments using the multi-repository approach.

## 🏗️ Architecture Overview

The CI/CD solution uses a **multi-repository approach** with **reusable GitHub Actions workflows** for enterprise-scale deployments:

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│   Infrastructure    │    │   Service Repos     │    │   APIM Tooling     │
│   Config Repo       │    │   (Multiple)        │    │   Repo (This)      │
├─────────────────────┤    ├─────────────────────┤    ├─────────────────────┤
│ • Environment       │    │ • API Specs         │    │ • Bicep Templates  │
│   Configurations    │    │ • API Configs       │    │ • Deployment       │
│ • Manual APIM       │    │ • Service Code      │    │   Scripts          │
│   Infrastructure    │    │ • Automated API     │    │ • Reusable         │
│   Deployment        │    │   Deployment        │    │   Workflows        │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## 📋 Repository Structure

### 1. **APIM Tooling Repository** (This Repository)
Contains reusable deployment logic and workflows that other repositories reference:

```
azure-apim-bicep/
├── .github/workflows/           # Reusable workflows
│   ├── deploy-infra.yml        # Infrastructure deployment
│   ├── deploy-api.yml          # API deployment  
│   └── validate-config.yml     # Configuration validation
├── bicep/                      # Infrastructure templates
├── scripts/                    # Deployment scripts
└── examples/github-actions/    # Example workflows to copy
    ├── infrastructure-repo/
    └── service-repo/
```

### 2. **Infrastructure Configuration Repository**
Manages environment configurations and infrastructure deployments:

```
infra-config-repo/
├── .github/workflows/
│   ├── deploy-infrastructure.yml    # Manual infrastructure deployment
│   └── validate-configs.yml         # Config validation on PR
├── environments/
│   ├── dev/config.env
│   ├── staging/config.env
│   └── prod/config.env
└── shared-specs/                   # Optional shared API specs
```

### 3. **Service Repositories**
Individual service repos with automated API deployment:

```
user-service-repo/
├── .github/workflows/
│   ├── deploy-api.yml             # Automated API deployment
│   └── validate-api.yml           # API validation on PR
├── src/                           # Service source code
├── specs/
│   └── api.openapi.yml           # API specification
└── deployment/
    └── api-config.yml            # APIM configuration
```

## 🚀 Quick Start

### Step 1: Set Up Infrastructure Repository

1. **Create infrastructure repository**:
   ```bash
   mkdir infra-config-repo
   cd infra-config-repo
   git init
   ```

2. **Copy example workflows**:
   ```bash
   mkdir -p .github/workflows
   
   # Copy from this repository's examples
   cp azure-apim-bicep/examples/github-actions/infrastructure-repo/*.yml .github/workflows/
   ```

3. **Create environment configurations**:
   ```bash
   mkdir -p environments/{dev,staging,prod}
   
   # Use the interactive setup or copy from examples
   # For each environment:
   cp azure-apim-bicep/examples/config.env.example environments/dev/config.env
   # Edit with your environment-specific values
   ```

4. **Configure repository secrets**:
   - `AZURE_CREDENTIALS`: Azure service principal JSON
   - `GITHUB_TOKEN`: Automatically provided by GitHub
   - Optional: `SLACK_WEBHOOK_URL` for notifications

### Step 2: Set Up Service Repository

1. **Copy example workflows**:
   ```bash
   mkdir -p .github/workflows
   cp azure-apim-bicep/examples/github-actions/service-repo/*.yml .github/workflows/
   ```

2. **Create API configuration**:
   ```bash
   mkdir -p deployment specs
   cp azure-apim-bicep/examples/api-config.yaml.example deployment/api-config.yml
   ```

3. **Update workflow variables**:
   Edit `.github/workflows/deploy-api.yml`:
   ```yaml
   env:
     SERVICE_NAME: your-service-name
     API_CONFIG_PATH: deployment/api-config.yml
     API_SPEC_PATH: specs/api.openapi.yml
   ```

4. **Configure repository secrets**:
   - `AZURE_CREDENTIALS`: Same as infrastructure repo
   - `CONFIG_REPO_TOKEN`: GitHub token with access to infrastructure repo

### Step 3: Configure Azure Credentials

1. **Create Azure service principal**:
   ```bash
   # Create service principal with contributor access
   az ad sp create-for-rbac --name "github-actions-apim" \
     --role contributor \
     --scopes /subscriptions/{subscription-id} \
     --sdk-auth
   ```

2. **Add to GitHub secrets** as `AZURE_CREDENTIALS`:
   ```json
   {
     "clientId": "...",
     "clientSecret": "...",
     "subscriptionId": "...",
     "tenantId": "..."
   }
   ```

## 🔄 Deployment Workflows

### Infrastructure Deployment (Manual)

Infrastructure deployments are **manual only** to prevent accidental changes:

```yaml
# Triggered manually from GitHub Actions UI
# Infrastructure repo: .github/workflows/deploy-infrastructure.yml

# 1. Select environment (dev/staging/prod)
# 2. Choose dry-run or actual deployment
# 3. Workflow validates and deploys APIM infrastructure
```

**Typical Flow**:
1. Developer updates environment configuration
2. Creates PR → Configuration validation runs
3. After PR merge → Manual infrastructure deployment
4. APIM instance ready for API deployments

### API Deployment (Automated)

API deployments are **automated based on branch merges**:

```yaml
# Service repo: .github/workflows/deploy-api.yml

develop branch → dev environment    # Automatic
main branch    → prod environment   # Automatic
manual trigger → any environment    # Manual with environment selection
```

**Typical Flow**:
1. Developer updates API spec/config
2. Creates PR → API validation runs
3. Merge to develop → Automatic deployment to dev
4. Merge to main → Automatic deployment to prod

## 🔧 Workflow Customization

### Environment Strategy

**Option 1: Branch-based** (Recommended):
```yaml
develop → dev
main → prod
```

**Option 2: Multi-branch**:
```yaml
develop → dev
staging → staging  
main → prod
```

**Option 3: Manual only**:
```yaml
# All deployments manual with environment selection
workflow_dispatch:
  inputs:
    environment:
      type: choice
      options: [dev, staging, prod]
```

### Deployment Modes

**Sync Mode** (Recommended for ongoing deployments):
- Only deploys changed APIs
- Faster deployment
- Automatic change detection

**Deploy Mode** (For initial deployments):
- Deploys all APIs
- Slower but comprehensive
- Use for new environments

### Parallel Deployment

Enable parallel API deployment for faster deployments:
```yaml
parallel-deployment: true  # Deploy multiple APIs simultaneously
```

## 🛡️ Security Best Practices

### Service Principal Permissions

Use **minimum required permissions** for Azure service principal:

```json
{
  "actions": [
    "Microsoft.ApiManagement/*",
    "Microsoft.Resources/deployments/*",
    "Microsoft.Resources/subscriptions/resourceGroups/*",
    "Microsoft.Network/*"
  ]
}
```

### Repository Access

**Infrastructure Repository**:
- Restrict write access to infrastructure team
- Require PR reviews for environment changes
- Use branch protection rules

**Service Repositories**:
- Service teams have full access to their repos
- Read-only access to infrastructure config repo
- Separate Azure credentials if needed

### Secret Management

**Centralized Secrets**:
- Store `AZURE_CREDENTIALS` in organization secrets
- Service-specific secrets in repository secrets
- Use GitHub environments for approval workflows

**Secret Rotation**:
- Regular rotation of service principal credentials
- Update GitHub secrets accordingly
- Test deployments after rotation

## 📊 Monitoring and Observability

### Deployment Tracking

**GitHub Deployments API**:
- Automatic deployment status tracking
- Environment-specific deployment history
- Integration with monitoring tools

**Notifications**:
- Slack/Teams integration for deployment results
- Email notifications for failures
- Custom webhook integrations

### Logging and Debugging

**Workflow Artifacts**:
- Deployment logs preserved for 30 days
- Configuration files uploaded as artifacts
- Debug information available in verbose mode

**Troubleshooting**:
```bash
# Enable debug mode in deployment
./apim.sh sync dev --debug

# Validate configuration
./apim.sh validate dev --verbose
```

## 🔍 Advanced Scenarios

### Multi-Environment Promotion

Create promotion workflows for staging → prod:

```yaml
name: Promote to Production
on:
  workflow_dispatch:
    inputs:
      from_environment: staging
      to_environment: prod
      
jobs:
  promote:
    # Copy artifacts from staging
    # Deploy to production  
    # Run production tests
```

### Rollback Capabilities

Implement rollback to previous versions:

```yaml
name: Rollback API
on:
  workflow_dispatch:
    inputs:
      environment: prod
      commit_sha: "abc123"  # Git SHA to rollback to
      
jobs:
  rollback:
    # Checkout specific commit
    # Deploy previous version
    # Verify rollback success
```

### Cross-Service Dependencies

Handle APIs that depend on other services:

```yaml
jobs:
  check-dependencies:
    # Verify dependent services are deployed
    # Check API compatibility
    # Validate integration endpoints
    
  deploy-with-dependencies:
    needs: check-dependencies
    # Deploy in dependency order
    # Run integration tests
```

## 🧪 Testing Strategies

### Pre-Deployment Testing

**Configuration Validation**:
- YAML/JSON syntax validation
- Required field verification
- Azure resource accessibility

**API Specification Testing**:
- OpenAPI/WSDL syntax validation
- Schema validation
- Documentation generation

### Post-Deployment Testing

**Smoke Tests**:
```yaml
post-deployment-test:
  steps:
  - name: Test API health endpoint
    run: |
      curl -f "https://apim-instance.azure-api.net/service/health"
```

**Integration Tests**:
```yaml
- name: Run integration tests
  run: |
    npm test -- --environment=${{ inputs.environment }}
```

**Performance Tests** (Production only):
```yaml
- name: Performance tests
  if: inputs.environment == 'prod'
  run: |
    k6 run performance-tests.js
```

## 🚨 Troubleshooting

### Common Issues

**Authentication Failures**:
```
Error: Failed to authenticate to Azure
Solution: Check AZURE_CREDENTIALS secret format
```

**Configuration Not Found**:
```
Error: Config file not found
Solution: Verify config-repo and config-path settings
```

**Permission Denied**:
```
Error: Insufficient permissions to create resource
Solution: Check service principal permissions
```

**Network Resource Conflicts**:
```
Error: Resource already exists
Solution: Review network reuse configuration
```

### Debug Steps

1. **Check workflow logs** for detailed error messages
2. **Validate configuration** using dry-run mode
3. **Verify Azure credentials** and permissions
4. **Test deployment scripts locally** if possible
5. **Check resource dependencies** and network configurations

### Getting Help

- **Workflow Issues**: Check GitHub Actions logs and artifacts
- **Azure Issues**: Use Azure CLI locally to reproduce issues  
- **Configuration Issues**: Run validation workflows
- **Network Issues**: Verify existing resource accessibility

## 📚 Best Practices Summary

### Repository Management
- ✅ Use separate repositories for infrastructure, services, and tooling
- ✅ Implement branch protection and required reviews
- ✅ Pin workflow versions for stability
- ✅ Regular security scanning and dependency updates

### Deployment Strategy
- ✅ Manual infrastructure deployment with approvals
- ✅ Automated API deployment on branch merges
- ✅ Use sync mode for faster deployments
- ✅ Implement comprehensive testing strategies

### Security
- ✅ Minimum required Azure permissions
- ✅ Regular secret rotation
- ✅ Environment-based access controls
- ✅ Audit trails and deployment tracking

### Monitoring
- ✅ Deployment notifications and alerts
- ✅ Post-deployment testing and validation
- ✅ Performance monitoring for production
- ✅ Rollback procedures and disaster recovery

---

This CI/CD setup provides enterprise-grade automated deployment capabilities while maintaining security, reliability, and observability for your Azure APIM infrastructure and APIs.