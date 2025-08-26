# GitHub Actions Workflow Examples

This directory contains example GitHub Actions workflows for implementing CI/CD with the Azure APIM deployment tooling.

## 📁 Directory Structure

### Infrastructure Repository Examples (`infrastructure-repo/`)
Copy these workflows to your **infrastructure configuration repository**:

- **`deploy-infrastructure.yml`** - Manual APIM infrastructure deployment with environment selection
- **`validate-configs.yml`** - Automatic validation of environment configurations on PRs

### Service Repository Examples (`service-repo/`)
Copy these workflows to your **service repositories** (one per API/service):

- **`deploy-api.yml`** - Automated API deployment on branch merges (develop→dev, main→prod)
- **`validate-api.yml`** - API configuration and specification validation on PRs

## 🚀 Quick Setup

### 1. Infrastructure Repository Setup

```bash
# Copy workflows to your infrastructure repo
mkdir -p .github/workflows
cp infrastructure-repo/*.yml your-infra-repo/.github/workflows/

# Update repository references
sed -i 's/your-org/YOUR_GITHUB_ORG/g' your-infra-repo/.github/workflows/*.yml
```

### 2. Service Repository Setup

```bash
# Copy workflows to your service repo  
mkdir -p .github/workflows
cp service-repo/*.yml your-service-repo/.github/workflows/

# Update configuration
# Edit .github/workflows/deploy-api.yml:
# - Change SERVICE_NAME to your service name
# - Update API_CONFIG_PATH and API_SPEC_PATH
# - Set your-org to your GitHub organization
```

## 🔧 Required Customizations

### Update Repository References
Replace placeholders in the workflow files:
- `your-org` → Your GitHub organization name
- `infra-config-repo` → Your infrastructure repository name
- `azure-apim-bicep` → Your APIM tooling repository name (if forked)

### Configure Secrets
Add these secrets to your repositories:

**Infrastructure Repository**:
- `AZURE_CREDENTIALS` - Azure service principal JSON

**Service Repositories**:
- `AZURE_CREDENTIALS` - Azure service principal JSON
- `CONFIG_REPO_TOKEN` - GitHub token with access to infrastructure repo

### Customize Environment Names
Update workflow environment options to match your setup:
```yaml
type: choice
options:
  - dev
  - staging  
  - prod
  - your-custom-env
```

## 📋 Workflow Features

### Infrastructure Workflows
- **Manual deployment** with environment selection
- **Dry-run capability** for validation
- **Comprehensive configuration validation** on PRs
- **Automatic PR commenting** with validation results

### Service Workflows  
- **Automatic deployment** on branch merges
- **Manual deployment** with environment selection
- **Parallel API deployment** for faster execution
- **Post-deployment testing** integration
- **Rollback support** via manual triggers

## 🛡️ Security Features

- **Environment-based approvals** for production deployments
- **Minimum Azure permissions** with service principal
- **Secret management** with GitHub secrets/environments
- **Deployment tracking** with GitHub Deployments API

## 📊 Monitoring Integration

The workflows include integration points for:
- **Slack/Teams notifications** (customize webhook URLs)
- **Deployment status tracking** via GitHub API
- **Artifact upload** for deployment logs and configurations
- **Test result reporting** in workflow summaries

## 🔍 Example Customizations

### Add Slack Notifications
```yaml
- name: Notify Slack
  run: |
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"Deployment completed: ${{ env.SERVICE_NAME }} to ${{ inputs.environment }}"}' \
      ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Add Environment-Specific Testing
```yaml
- name: Run environment-specific tests
  run: |
    if [[ "${{ inputs.environment }}" == "prod" ]]; then
      npm run test:prod
    else
      npm run test:dev  
    fi
```

### Add Approval Requirements
```yaml
jobs:
  deploy:
    environment: 
      name: ${{ inputs.environment }}
      url: https://your-apim.azure-api.net
    # GitHub will require approval for protected environments
```

## 🚨 Common Issues

### Workflow Not Triggering
- Check branch names match your setup (develop, main)
- Verify file paths in workflow triggers
- Ensure workflows are in `.github/workflows/` directory

### Permission Errors
- Verify Azure service principal has sufficient permissions
- Check GitHub token has access to config repository
- Ensure environment protection rules allow deployment

### Configuration Not Found
- Verify config-repo and config-path parameters
- Check repository references are correct
- Ensure config files exist in expected locations

## 📚 Additional Resources

- **[Complete Setup Guide](../../CICD.md)** - Comprehensive CI/CD implementation guide
- **[Main README](../../README.md)** - APIM deployment tool documentation
- **[Configuration Examples](../config.env.example)** - Environment configuration templates

## 🆘 Support

If you encounter issues:
1. Check workflow logs for detailed error messages
2. Validate configurations using the validation workflows
3. Test deployment scripts locally if possible
4. Review the troubleshooting section in the main documentation