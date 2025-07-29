# GitLab CI/CD Modular Pipeline Structure

This directory contains the modularized GitLab CI/CD pipeline files for the eShop .NET Aspire project.

## Structure

```
.gitlab-ci/
├── README.md              # This documentation file
├── validate.yaml          # Validation stage jobs
├── test.yaml             # Test stage jobs (commented out)
├── build.yaml            # Build stage jobs
├── docker-build.yaml     # Docker build stage jobs
├── security-scan.yaml    # Security scan stage jobs
└── deploy.yaml           # Deploy stage jobs
```

## Files Description

### `validate.yaml`
Contains the validation job that checks code quality and dependencies:
- Restores NuGet packages
- Builds the solution
- Checks for vulnerable and deprecated packages

### `test.yaml`
Contains the test job (currently commented out):
- Runs unit and integration tests
- Generates code coverage reports
- Uses PostgreSQL, Redis, and RabbitMQ services

### `build.yaml`
Contains the build job that compiles and publishes the application:
- Restores dependencies
- Builds the solution
- Publishes the application

### `docker-build.yaml`
Contains all Docker build jobs that extend the `.build-dotnet-service` template:
- 11 individual service build jobs
- Each job builds and pushes a specific service image
- Uses the template for consistency and maintainability

### `security-scan.yaml`
Contains the security scanning job:
- Scans Docker images for vulnerabilities using Trivy
- Generates security reports
- Depends on Docker build jobs

### `deploy.yaml`
Contains deployment jobs:
- Kubernetes deployment job
- Manual deployment with approval gates
- Depends on all Docker build jobs

## Main Pipeline File

The main `.gitlab-ci.yml` file in the root directory contains:
- Pipeline stages definition
- Global variables
- Cache configuration
- Template definitions
- Include statements for modular files

## Benefits of Modular Structure

1. **Maintainability**: Each stage is in its own file, making it easier to maintain
2. **Reusability**: Individual stage files can be reused in other projects
3. **Clarity**: Clear separation of concerns
4. **Scalability**: Easy to add new stages or modify existing ones
5. **Team Collaboration**: Different team members can work on different stages

## Adding New Stages

To add a new stage:

1. Create a new YAML file in this directory (e.g., `new-stage.yaml`)
2. Add the stage to the `stages` list in the main `.gitlab-ci.yml` file
3. Add an include statement in the main `.gitlab-ci.yml` file:
   ```yaml
   include:
     - local: '.gitlab-ci/new-stage.yaml'
   ```

## Template Usage

The `.build-dotnet-service` template in the main file provides a consistent way to build Docker images. To add a new service:

1. Add a new job in `docker-build.yaml`
2. Extend the template:
   ```yaml
   docker-build-new-service:
     extends: .build-dotnet-service
     variables:
       SERVICE_NAME: "new-service"
       DOCKERFILE_PATH: "src/NewService/Dockerfile"
   ```

## Variables

Global variables are defined in the main `.gitlab-ci.yml` file and are available to all jobs in the modular files. Service-specific variables are defined in each job's `variables` section. 