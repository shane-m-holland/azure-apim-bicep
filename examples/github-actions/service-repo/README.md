# Service Repository Examples

This directory contains example GitHub Actions workflows for deploying APIs to Azure API Management from your service repositories.

## 📁 Available Examples

### 🚀 **deploy-api.yml** - Modern Artifact-Based Approach
**Recommended for new projects**

- **Generates API specifications** during the build process
- **Uploads specs as artifacts** for deployment
- **Best for**: Code-first API development where specs are generated from annotations/decorators
- **Technologies**: ASP.NET Core, Spring Boot, FastAPI, Express.js with Swagger, etc.

```yaml
# Example usage in your workflow
- name: Generate API spec
  run: |
    # Generate from ASP.NET Core
    curl -o specs/api.json http://localhost:5000/swagger/v1/swagger.json
    
    # Generate from Spring Boot  
    curl -o specs/api.json http://localhost:8080/v3/api-docs
    
    # Generate from FastAPI
    curl -o specs/api.json http://localhost:8000/openapi.json
```

### 📁 **deploy-api-traditional.yml** - Repository-Based Approach  
**For existing projects with committed specs**

- **Uses API specifications** committed to the repository
- **Direct file-based deployment** without artifacts
- **Best for**: Design-first API development, hand-written OpenAPI specs, WSDL files
- **Migration path**: Use this while transitioning to artifact-based approach

```yaml
# Your repository structure
service-repo/
├── specs/
│   ├── api.openapi.yml     # Committed spec file
│   └── legacy.wsdl
├── deployment/
│   └── api-config.yml
```

### 🔄 **deploy-api-hybrid.yml** - Flexible Hybrid Approach
**For migration scenarios and maximum flexibility**

- **Tries to generate** specifications first
- **Falls back to committed** specs if generation fails
- **Best for**: Migration scenarios, mixed environments, resilient deployments
- **Use cases**: Different approaches per environment, gradual migration

## 🔧 Configuration Comparison

| Feature | Artifact-Based | Traditional | Hybrid |
|---------|---------------|-------------|---------|
| **Spec Source** | Generated from code | Committed files | Auto-detect |
| **Maintenance** | Low (automated) | High (manual) | Medium |
| **Code-Spec Sync** | Always in sync | Manual sync needed | Best of both |
| **Setup Complexity** | Medium | Low | High |
| **Flexibility** | Low | Low | High |
| **Recommended For** | New projects | Legacy projects | Migration |

## 🚀 Getting Started

### 1. Choose Your Approach

**For new projects**: Start with **deploy-api.yml** (artifact-based)
```bash
cp deploy-api.yml .github/workflows/deploy-api.yml
```

**For existing projects**: Use **deploy-api-traditional.yml**
```bash
cp deploy-api-traditional.yml .github/workflows/deploy-api.yml
```

**For migration**: Use **deploy-api-hybrid.yml**
```bash
cp deploy-api-hybrid.yml .github/workflows/deploy-api.yml
```

### 2. Customize the Workflow

Edit the copied workflow file and update:

```yaml
env:
  SERVICE_NAME: your-service-name        # Change this
  API_CONFIG_PATH: deployment/api-config.yml
  # API_SPEC_PATH: specs/api.openapi.yml  # Only for traditional approach
```

### 3. Update Repository References

Replace `your-org` with your GitHub organization:

```yaml
uses: your-org/azure-apim-bicep/.github/workflows/deploy-api.yml@v1
config-repo: your-org/infra-config-repo
```

### 4. Configure Secrets

Add these secrets to your repository:

- `AZURE_CREDENTIALS` - Azure service principal JSON
- `CONFIG_REPO_TOKEN` - GitHub token for accessing config repository (optional for public repos)

## 📋 Workflow Inputs

### Common Inputs (All Approaches)

| Input | Description | Default |
|-------|-------------|---------|
| `environment` | Target environment (dev/staging/prod) | Auto-detected from branch |
| `deployment_mode` | sync (changed only) or deploy (all) | `sync` |
| `dry_run` | Validate without deploying | `false` |

### Artifact-Based Specific

| Input | Description | Default |
|-------|-------------|---------|
| `use-spec-artifact` | Use artifact for API spec | `true` |
| `spec-artifact-name` | Name of spec artifact | `api-specs` |
| `spec-artifact-path` | Path within artifact | Auto-detected |

### Traditional Specific

| Input | Description | Default |
|-------|-------------|---------|
| `api-spec-path` | Path to committed spec file | `specs/api.openapi.yml` |

## 🔍 Validation Examples

Each deployment approach has a corresponding validation workflow:

### **validate-api.yml** - Artifact-Based Validation
- Generates specs for validation
- Tests generated specifications
- Validates against APIM deployment (dry-run)

### **validate-api-traditional.yml** - Traditional Validation  
- Validates committed specification files
- Checks API configuration syntax
- Tests deployment compatibility

Copy the appropriate validation workflow:

```bash
# For artifact-based approach
cp validate-api.yml .github/workflows/validate-api.yml

# For traditional approach (create this file)
# Use the same structure but without spec generation steps
```

## 🔄 Migration Guide

### From Traditional to Artifact-Based

1. **Start with hybrid approach**:
   ```bash
   cp deploy-api-hybrid.yml .github/workflows/deploy-api.yml
   ```

2. **Add spec generation** to your build process
3. **Test with `spec_source: generate`** input
4. **Switch to pure artifact-based** once stable:
   ```bash
   cp deploy-api.yml .github/workflows/deploy-api.yml
   ```

### From Artifact-Based to Traditional

1. **Commit your generated specs** to the repository
2. **Switch to traditional workflow**:
   ```bash
   cp deploy-api-traditional.yml .github/workflows/deploy-api.yml
   ```

## 🛠️ Spec Generation Examples

### ASP.NET Core with Swashbuckle
```bash
# Start API in background
dotnet run --project src/YourAPI --urls "http://localhost:5000" &
sleep 10

# Download generated spec
curl -o generated-specs/api.json http://localhost:5000/swagger/v1/swagger.json
```

### Spring Boot with SpringDoc
```bash
# Start application
./mvnw spring-boot:run -Dspring-boot.run.arguments="--server.port=8080" &
sleep 15

# Download spec
curl -o generated-specs/api.json http://localhost:8080/v3/api-docs
```

### FastAPI
```bash
# Start FastAPI app
uvicorn src.main:app --host 0.0.0.0 --port 8000 &
sleep 10

# Download OpenAPI spec
curl -o generated-specs/api.json http://localhost:8000/openapi.json
```

### Node.js/Express with Swagger
```bash
# Start Express app
npm start &
sleep 10

# Download spec (adjust endpoint based on your setup)
curl -o generated-specs/api.json http://localhost:3000/api-docs.json
```

## 🔧 Troubleshooting

### Common Issues

**Artifact not found**:
- Ensure spec generation step succeeds
- Check artifact name matches deployment workflow
- Verify artifact retention period

**Spec validation fails**:
- Test spec generation locally first
- Use swagger-cli to validate: `swagger-cli validate spec.json`
- Check for code changes that break spec generation

**Traditional specs out of sync**:
- Consider switching to artifact-based approach
- Use hybrid approach during transition
- Set up automated spec updates

### Debug Steps

1. **Check workflow logs** for spec generation output
2. **Download artifacts** manually to inspect contents
3. **Run validation locally** with same tools
4. **Test spec generation** in development environment

## 📚 Additional Resources

- [Azure APIM Bicep Repository](../../../)
- [OpenAPI Specification](https://swagger.io/specification/)
- [GitHub Actions Artifacts](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)
- [Swagger CLI Tools](https://github.com/APIDevTools/swagger-cli)