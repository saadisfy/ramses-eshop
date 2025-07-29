# General .NET Knowledge: Project Structure and Aspire

This document explains the structure of modern .NET projects, the role of .NET Aspire, and how microservices architectures work in the .NET ecosystem.

## .NET Project Structure Overview

### Top-Level Configuration Files

Modern .NET solutions use a hierarchical configuration system:

```
eShop/
├── eShop.sln                    # Solution file - defines all projects
├── Directory.Build.props        # Global build properties for all projects
├── Directory.Packages.props     # Centralized package management (CPM)
├── Directory.Build.targets      # Global build targets
├── global.json                  # .NET SDK version specification
├── nuget.config                 # NuGet sources configuration
└── .editorconfig               # Code style configuration
```

#### Key Configuration Patterns:

**Directory.Build.props** - Applies to all projects:
```xml
<Project>
  <PropertyGroup>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <ImplicitUsings>enable</ImplicitUsings>
    
    <!-- Global Container Configuration -->
    <PublishProfile>DefaultContainer</PublishProfile>
    <ContainerRegistry>ghcr.io</ContainerRegistry>
    <ContainerImageTags>$(Version)</ContainerImageTags>
  </PropertyGroup>
</Project>
```

**Directory.Packages.props** - Centralized package versions:
```xml
<Project>
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="9.0.1" />
    <PackageReference Include="Aspire.Npgsql.EntityFrameworkCore.PostgreSQL" Version="9.2.0" />
  </ItemGroup>
</Project>
```

### Source Structure (`src/`)

#### Microservices Architecture Components:

**Core Microservices** (Independent deployable services):
- `Basket.API/` - Shopping basket service
- `Catalog.API/` - Product catalog service  
- `Identity.API/` - Authentication/authorization service
- `Ordering.API/` - Order management service
- `Webhooks.API/` - Webhook management service

**Background Services**:
- `OrderProcessor/` - Processes orders asynchronously
- `PaymentProcessor/` - Handles payment processing

**Client Applications**:
- `WebApp/` - Main web application (Blazor Server)
- `ClientApp/` - Mobile client (.NET MAUI)
- `HybridApp/` - Hybrid web/mobile app
- `WebhookClient/` - Webhook client demo

**Shared Libraries**:
- `eShop.ServiceDefaults/` - Common services for all microservices
- `EventBus/` - Event bus abstractions
- `EventBusRabbitMQ/` - RabbitMQ implementation
- `IntegrationEventLogEF/` - Event sourcing support
- `Shared/` - Common utilities

**Backend for Frontend (BFF)**:
- `Mobile.Bff.Shopping/` - API gateway for mobile clients

**Aspire Orchestration** (Development only):
- `eShop.AppHost/` - Development orchestration

### Individual Microservice Structure

Each microservice follows a consistent pattern:

```
Catalog.API/
├── Catalog.API.csproj          # Project file with dependencies
├── Program.cs                  # Entry point and service configuration
├── appsettings.json           # Base configuration
├── appsettings.Development.json # Dev-specific config
├── Dockerfile                 # Optional traditional Docker build
├── Apis/                      # Minimal API endpoints
├── Extensions/                # Service registration extensions
├── Infrastructure/           # Data access, repositories
├── Model/                    # Domain models
├── Services/                 # Business logic
└── Properties/               # Assembly metadata
```

## .NET Aspire: Development Orchestration

### What is .NET Aspire?

.NET Aspire is a **development-time orchestration framework** that:
- Manages local development environments
- Orchestrates microservices and their dependencies
- Provides service discovery and configuration
- Handles infrastructure services (databases, message queues)
- **Is NOT used in production deployments**

### AppHost Role and Functionality

The `eShop.AppHost` project serves as the orchestration center:

```csharp
// eShop.AppHost/Program.cs
var builder = DistributedApplication.CreateBuilder(args);

// Infrastructure Services
var redis = builder.AddRedis("redis");
var rabbitMq = builder.AddRabbitMQ("eventbus")
    .WithLifetime(ContainerLifetime.Persistent);
var postgres = builder.AddPostgres("postgres")
    .WithImage("ankane/pgvector")
    .WithImageTag("latest")
    .WithLifetime(ContainerLifetime.Persistent);

// Database creation
var catalogDb = postgres.AddDatabase("catalogdb");
var identityDb = postgres.AddDatabase("identitydb");
var orderDb = postgres.AddDatabase("orderingdb");

// Service orchestration
var identityApi = builder.AddProject<Projects.Identity_API>("identity-api")
    .WithExternalHttpEndpoints()
    .WithReference(identityDb);

var basketApi = builder.AddProject<Projects.Basket_API>("basket-api")
    .WithReference(redis)
    .WithReference(rabbitMq).WaitFor(rabbitMq)
    .WithEnvironment("Identity__Url", identityEndpoint);
```

### AppHost Project Structure:

```xml
<!-- eShop.AppHost.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <Sdk Name="Aspire.AppHost.Sdk" Version="9.2.0" />
  
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net9.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.AppHost" />
    <PackageReference Include="Aspire.Hosting.RabbitMQ" />
    <PackageReference Include="Aspire.Hosting.Redis" />
    <PackageReference Include="Aspire.Hosting.PostgreSQL" />
  </ItemGroup>

  <ItemGroup>
    <!-- References to all microservices -->
    <ProjectReference Include="..\Basket.API\Basket.API.csproj" />
    <ProjectReference Include="..\Catalog.API\Catalog.API.csproj" />
    <!-- ... more services -->
  </ItemGroup>
</Project>
```

## ServiceDefaults: The Bridge Pattern

### Core Concept

`eShop.ServiceDefaults` provides the **crucial bridge** between Aspire development and production deployment:

```csharp
// Every microservice calls this in Program.cs
builder.AddServiceDefaults();
```

### What ServiceDefaults Provides:

```csharp
public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder)
{
    builder.AddBasicServiceDefaults();

    // Service Discovery (works in both Aspire and production)
    builder.Services.AddServiceDiscovery();

    // HTTP client configuration with resilience
    builder.Services.ConfigureHttpClientDefaults(http =>
    {
        http.AddStandardResilienceHandler();  // Polly retry policies
        http.AddServiceDiscovery();          // Logical name resolution
    });

    return builder;
}

public static IHostApplicationBuilder AddBasicServiceDefaults(this IHostApplicationBuilder builder)
{
    // Health checks for container orchestration
    builder.AddDefaultHealthChecks();
    
    // Observability (OpenTelemetry)
    builder.ConfigureOpenTelemetry();
    
    return builder;
}
```

### ServiceDefaults Components:

1. **Health Checks**: Used by Docker/Kubernetes for readiness/liveness probes
2. **OpenTelemetry**: Distributed tracing, metrics, and logging
3. **Service Discovery**: Logical service name resolution
4. **Authentication**: JWT token handling
5. **Resilience**: Retry policies and circuit breakers

## Container Generation vs. Traditional Dockerfiles

### Modern .NET Container Generation

Instead of writing Dockerfiles, modern .NET uses built-in container generation:

```xml
<!-- In project file -->
<PropertyGroup>
  <ContainerImageName>saadisfy/eShop/catalog-api</ContainerImageName>
  <Version>1.0.0</Version>
</PropertyGroup>
```

```bash
# CI/CD generates containers directly
dotnet publish $PROJECT_PATH \
  --configuration Release \
  -p:ContainerRegistry=ghcr.io \
  -p:ContainerRepository=$GITHUB_USERNAME/eShop/$SERVICE_NAME \
  -p:ContainerImageTags=$PROJECT_VERSION
```

### Benefits of Built-in Container Generation:

1. **No Dockerfile maintenance**
2. **Automatic optimizations**
3. **Consistent base images**
4. **Security updates handled by Microsoft**
5. **Smaller attack surface**

## Key Architectural Patterns

### 1. Centralized Package Management (CPM)
All package versions defined in one place (`Directory.Packages.props`).

### 2. ServiceDefaults Pattern
Shared configuration across all microservices.

### 3. Event-Driven Architecture
Using RabbitMQ for asynchronous communication between services.

### 4. API Gateway Pattern
BFF (Backend for Frontend) for different client types.

### 5. Configuration Hierarchy
Base configuration + environment-specific overrides.

## Development vs. Production

| Aspect | Aspire (Development) | Production |
|--------|---------------------|------------|
| **Orchestration** | AppHost manages everything | Kubernetes/Docker orchestration |
| **Service Discovery** | Automatic via Aspire | Manual configuration or K8s DNS |
| **Infrastructure** | Automatically provisioned containers | Managed services or dedicated infrastructure |
| **Configuration** | Injected by Aspire | Environment variables/ConfigMaps |
| **Health Checks** | Built-in monitoring | Container orchestration health probes |
| **Networking** | Automatic port allocation | Load balancers, ingress controllers |

## Summary

This architecture represents a **modern, cloud-native .NET approach** using:
- **Aspire for development simplicity** (local orchestration)
- **ServiceDefaults for production readiness** (shared infrastructure)
- **Container generation** instead of Dockerfiles
- **Centralized configuration management**
- **Event-driven microservices communication**

The key insight is that **application code remains the same** between development and production - only the infrastructure and configuration delivery mechanisms change. 