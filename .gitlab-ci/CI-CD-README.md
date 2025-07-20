# GitLab CI/CD Pipeline for eShop .NET Aspire Project

This document describes the GitLab CI/CD pipeline setup for the eShop .NET Aspire project, which follows best practices for containerized .NET applications.

## Overview

The pipeline is designed to build, test, and deploy a microservices-based eCommerce application built with .NET Aspire. It includes Docker image building, security scanning, and deployment stages.

## Pipeline Stages

### 1. Validate Stage
- **Purpose**: Validates project structure and dependencies
- **Actions**:
  - Restores NuGet packages
  - Builds the solution
  - Checks for vulnerable and deprecated packages
- **Triggers**: Merge requests, main branch, feature branches

### 2. Test Stage
- **Purpose**: Runs unit and integration tests
- **Services**: PostgreSQL, Redis, RabbitMQ
- **Actions**:
  - Runs all tests with code coverage
  - Generates coverage reports
  - Collects test results
- **Triggers**: Merge requests, main branch, feature branches

### 3. Build Stage
- **Purpose**: Builds the application for deployment
- **Actions**:
  - Restores dependencies
  - Builds the solution
  - Publishes the application
- **Triggers**: Merge requests, main branch, feature branches

### 4. Docker Build Stage
- **Purpose**: Builds Docker images for all services
- **Services**: Docker-in-Docker
- **Actions**:
  - Builds images for all microservices
  - Tags images with commit SHA and branch name
  - Pushes images to container registry
  - Tags as 'latest' for main branch
- **Triggers**: Main branch, feature branches, release branches

### 5. Security Scan Stage
- **Purpose**: Scans Docker images for vulnerabilities
- **Tool**: Trivy
- **Actions**:
  - Scans all built images
  - Generates security reports
- **Triggers**: Main branch, release branches

### 6. Deploy Stage
- **Purpose**: Deploys to different environments
- **Environments**: Staging, Production
- **Actions**:
  - Manual deployment to staging
  - Manual deployment to production
- **Triggers**: Main branch (manual approval required)

## Services Built

The pipeline builds Docker images for the following services:

1. **eShop.AppHost** - The main Aspire application host
2. **Basket.API** - Shopping basket service
3. **Catalog.API** - Product catalog service
4. **Identity.API** - Authentication and authorization service
5. **Ordering.API** - Order management service
6. **OrderProcessor** - Background order processing service
7. **PaymentProcessor** - Payment processing service
8. **Webhooks.API** - Webhook management service
9. **WebApp** - Main web application
10. **WebhookClient** - Webhook client application
11. **Mobile.Bff.Shopping** - Mobile backend for frontend

## Configuration

### Required GitLab Variables

Set the following variables in your GitLab project settings:

```bash
# Registry Configuration
CI_REGISTRY=your-registry-url
CI_REGISTRY_IMAGE=your-registry/your-project
CI_REGISTRY_USER=your-username
CI_REGISTRY_PASSWORD=your-password

# Optional: Custom registry (if not using GitLab's built-in registry)
REGISTRY_URL=your-custom-registry-url
REGISTRY_IMAGE=your-custom-registry/your-project
REGISTRY_USER=your-username
REGISTRY_PASSWORD=your-password
```

### Environment Variables

The pipeline uses the following environment variables:

- `DOTNET_VERSION`: .NET SDK version (default: 9.0.x)
- `BUILD_CONFIGURATION`: Build configuration (default: Release)
- `BUILD_PLATFORM`: Target platform (default: linux-x64)

## Docker Images

### Image Naming Convention

Images are tagged with the following pattern:
- `{registry}/{service}:{commit-sha}` - Specific commit
- `{registry}/{service}:{branch-name}` - Branch-specific
- `{registry}/{service}:latest` - Latest version (main branch only)

### Example Image Names

```
your-registry/your-project/apphost:abc123
your-registry/your-project/basket-api:main
your-registry/your-project/catalog-api:latest
```

## Security Features

### Vulnerability Scanning

The pipeline includes Trivy for vulnerability scanning:
- Scans all built Docker images
- Generates JSON reports
- Stores results as artifacts

### Best Practices Implemented

1. **Multi-stage builds** for smaller runtime images
2. **Non-root user** execution (where applicable)
3. **Health checks** for all services
4. **Security scanning** with Trivy
5. **Dependency caching** for faster builds
6. **Cleanup** of old images

## Deployment

### Staging Deployment

- Triggered automatically on main branch
- Requires manual approval
- Deploys to staging environment

### Production Deployment

- Triggered manually on main branch
- Requires manual approval
- Deploys to production environment

### Custom Deployment

To customize deployment, modify the deploy jobs in `.gitlab-ci.yml`:

```yaml
deploy-staging:
  script:
    # Add your deployment logic here
    - kubectl apply -f k8s/staging/
    - helm upgrade --install eshop ./helm-chart --namespace staging
```

## Monitoring and Observability

### Health Checks

All services include health check endpoints:
- HTTP health checks for web services
- Process health checks for background services

### Logging

- Structured logging with Serilog
- OpenTelemetry integration
- Distributed tracing support

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check .NET SDK version compatibility
   - Verify all project references are correct
   - Ensure all required packages are restored

2. **Docker Build Failures**
   - Verify Dockerfile paths are correct
   - Check for missing dependencies
   - Ensure registry credentials are set

3. **Test Failures**
   - Verify database connections
   - Check service dependencies
   - Review test configuration

### Debug Mode

To enable debug mode, add the following variable:
```bash
DOTNET_CLI_TELEMETRY_OPTOUT=0
```

## Performance Optimization

### Build Optimization

1. **Layer Caching**: Docker layers are cached for faster builds
2. **Dependency Caching**: NuGet packages are cached between builds
3. **Parallel Builds**: Services can be built in parallel
4. **Multi-stage Builds**: Smaller runtime images

### Registry Optimization

1. **Image Cleanup**: Old images are automatically cleaned up
2. **Tagging Strategy**: Efficient tagging for different environments
3. **Registry Mirroring**: Support for custom registries

## Best Practices

### Code Quality

1. **Static Analysis**: Built-in .NET analyzers
2. **Package Security**: Vulnerability scanning
3. **Code Coverage**: Minimum coverage requirements

### Security

1. **Image Scanning**: Regular vulnerability scans
2. **Secret Management**: Secure handling of secrets
3. **Access Control**: Principle of least privilege

### Reliability

1. **Health Checks**: Comprehensive health monitoring
2. **Rollback Strategy**: Easy rollback capabilities
3. **Monitoring**: Full observability stack

## Contributing

When contributing to the pipeline:

1. Test changes in a feature branch
2. Follow the existing naming conventions
3. Update documentation for new features
4. Ensure backward compatibility

## Support

For issues or questions:

1. Check the troubleshooting section
2. Review GitLab CI/CD documentation
3. Consult .NET Aspire documentation
4. Create an issue in the project repository

## License

This pipeline configuration is part of the eShop project and follows the same licensing terms. 