# How to Version and Release Microservices

This guide explains the versioning strategy for the eShop microservices architecture and how to properly release new versions.

## Version Types Explained

### **Version (Semantic Version)**
- **Format**: `MAJOR.MINOR.PATCH` (e.g., `2.1.0`)
- **Purpose**: Human-readable version for releases and container tags
- **Location**: `<Version>` property in `.csproj` files
- **Usage**: Container image tags, release notes, API documentation

**Note**: In this project, we use the application version as the container image tag version. While typically there might be separate versioning for application code vs. container image layers (base images, dependencies, etc.), we simplify this by using the application version for both. This reduces complexity and ensures consistency between application releases and container image tags.

## Current Microservice Versions

| Service | Version | Container Image |
|---------|---------|-----------------|
| Catalog.API | 1.0.0 | `ghcr.io/saadisfy/eShop/catalog-api:1.0.0` |
| Basket.API | 1.0.0 | `ghcr.io/saadisfy/eShop/basket-api:1.0.0` |
| Ordering.API | 1.0.0 | `ghcr.io/saadisfy/eShop/ordering-api:1.0.0` |
| Identity.API | 1.0.0 | `ghcr.io/saadisfy/eShop/identity-api:1.0.0` |

## How Versioning Works

### Property Inheritance
- **Explicit versioning**: Each microservice must define its own `<Version>` property
- **No global fallback**: No default version in `Directory.Build.props`
- **Enforced versioning**: Build will fail if a service doesn't have a version defined

### Container Configuration
- **Registry**: `ghcr.io` (set globally in `Directory.Build.props`)
- **Image Name**: Service-specific (e.g., `saadisfy/eShop/catalog-api`)
- **Tags**: Uses the service's `$(Version)` property (must be explicitly defined)
- **Versioning Strategy**: Application version = Container image tag version (simplified approach)

## How to Update Versions

### Step 1: Determine Version Type
Follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes (API changes, database schema changes)
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Step 2: Update Service Version
Edit the service's `.csproj` file:

```xml
<!-- Example: Updating Catalog.API from 2.1.0 to 2.2.0 -->
<PropertyGroup>
  <!-- Microservice Versioning -->
  <Version>2.2.0</Version>
  
  <!-- Container Configuration -->
  <ContainerImageName>saadisfy/eShop/catalog-api</ContainerImageName>
</PropertyGroup>
```

### Step 3: Update Version Property
**Update the Version property for container image releases:**
```xml
<Version>2.2.0</Version>           <!-- Semantic version for container tags -->
```

### Step 4: Commit and Push
```bash
git add src/Catalog.API/Catalog.API.csproj
git commit -m "feat: bump Catalog.API version to 2.2.0"
git push
```

## Version Update Examples

### Minor Version Update (New Features)
```xml
<!-- Before -->
<Version>2.1.0</Version>

<!-- After -->
<Version>2.2.0</Version>
```

### Major Version Update (Breaking Changes)
```xml
<!-- Before -->
<Version>2.1.0</Version>

<!-- After -->
<Version>3.0.0</Version>
```

### Patch Version Update (Bug Fixes)
```xml
<!-- Before -->
<Version>2.1.0</Version>

<!-- After -->
<Version>2.1.1</Version>
```

## Container Image Generation

### Automatic Tagging
When you run `dotnet publish` with container parameters, the image is automatically tagged with the service's version:

```bash
dotnet publish src/Catalog.API/Catalog.API.csproj \
  --configuration Release \
  -p:ContainerRegistry=ghcr.io \
  -p:ContainerImageName=saadisfy/eShop/catalog-api \
  -p:ContainerImageTags=2.2.0 \
  -p:ContainerUsername=saadisfy \
  -p:ContainerPassword=your-token
```

**Result**: `ghcr.io/saadisfy/eShop/catalog-api:2.2.0`

### GitLab CI Integration
The CI pipeline automatically uses the service's version for container tagging:

```yaml
-p:ContainerImageTags=$(Version)  # Uses the service's Version property
```

## Best Practices

### 1. **Independent Versioning**
- Each microservice can evolve independently
- No need to version all services together
- Update only the services that change
- Application version directly maps to container image tag version

### 2. **Semantic Versioning**
- Follow MAJOR.MINOR.PATCH format
- Document breaking changes clearly
- Use conventional commit messages

### 3. **Semantic Versioning**
- Use semantic versioning (MAJOR.MINOR.PATCH) for releases
- Focus on meaningful version increments
- Document breaking changes clearly

### 4. **Release Process**
1. Update version in `.csproj`
2. Commit with descriptive message
3. Push to trigger CI/CD
4. Verify container image is published with correct tag
5. Update release notes/documentation

## Troubleshooting

### Version Not Updating
- Check that you updated the `<Version>` property
- Ensure the service's `.csproj` has the version defined
- Verify the CI pipeline uses `$(Version)` for tagging

### Container Image Issues
- Confirm `ContainerImageName` doesn't include registry
- Verify `ContainerRegistry` is set to `ghcr.io`
- Check that `ContainerImageTags` uses `$(Version)`

### Version Conflicts
- Check for any hardcoded version references in code
- Verify no dependency issues in dependent services

## Quick Reference

### Version Update Checklist
- [ ] Update `<Version>` property
- [ ] Commit changes with descriptive message
- [ ] Push to trigger CI/CD
- [ ] Verify container image is published with correct tag

### Common Commands
```bash
# Check current version
dotnet build --configuration Release

# Publish with container generation
dotnet publish --configuration Release -p:PublishProfile=DefaultContainer

# Check container image tags
docker images | grep saadisfy/eShop
``` 