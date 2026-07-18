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

### 6. EventBus and Message-Driven Architecture
Decoupled communication through events using RabbitMQ as transport.

## EventBus Architecture: Message-Driven Microservices

### What is an EventBus?

An **EventBus** is an **architectural pattern** that enables **decoupled communication** between microservices through events. It serves as a "communication highway" where services can:

- **Publish events** when something important happens (business events)
- **Subscribe to events** they care about from other services
- **React to events** asynchronously without direct service coupling

### EventBus vs RabbitMQ: Layered Architecture

```
┌─────────────┐    publishes    ┌──────────────┐    routes via    ┌─────────────┐
│   Service   │ ─────────────► │   EventBus   │ ──────────────► │  RabbitMQ   │
│ (Catalog)   │                │ (Abstraction)│                 │ (Transport) │
└─────────────┘                └──────────────┘                 └─────────────┘
                                        │                              │
                               ┌────────▼────────┐            ┌────────▼────────┐
                               │ - Event routing │            │ - Queues        │
                               │ - Event types   │            │ - Exchanges     │
                               │ - Subscriptions │            │ - Routing keys  │
                               └─────────────────┘            └─────────────────┘
```

#### EventBus = **Business Logic Layer**
- Defines **what** events to send/receive (business semantics)
- Handles **event serialization/deserialization** (JSON, XML)
- Manages **subscriptions** and **event type routing**
- Provides **retry logic** and **dead letter handling**
- Offers **type-safe event contracts**

#### RabbitMQ = **Infrastructure Transport Layer**  
- Handles **how** messages are delivered (AMQP protocol)
- Manages **queues**, **exchanges**, and **routing keys**
- Ensures **message persistence** and **delivery guarantees**
- Provides **network transport** and **clustering**
- Handles **connection management** and **failover**

### EventBus Implementation in eShop

#### Configuration in Helm Templates

The EventBus configuration is injected via environment variables in the deployment:

```yaml
# From helm/charts/catalog-api-v2/charts/baseChart/templates/deployment.yaml
{{- if .Values.sharedServices.rabbitmq.enabled }}
# Event Bus connection (when enabled)
- name: ConnectionStrings__EventBus
  value: "amqp://{{ .Values.sharedServices.rabbitmq.username }}:{{ .Values.sharedServices.rabbitmq.password }}@{{ .Values.sharedServices.rabbitmq.serviceName }}:{{ .Values.sharedServices.rabbitmq.port }}"

# Event Bus configuration
- name: EventBus__SubscriptionClientName
  value: {{ include "application.eventBusClientName" . | quote }}
- name: EventBus__RetryCount
  value: "10"
{{- end }}
```

#### Key Configuration Elements:

1. **Connection String**: `amqp://user:password@catalog-api-v2-rabbitmq:5672`
   - Uses **AMQP (Advanced Message Queuing Protocol)**
   - Points to the RabbitMQ service instance
   - Includes authentication credentials

2. **Subscription Client Name**: `"Catalog"`
   - **Identifies this specific service** instance
   - Used for **queue naming** and **routing**
   - Enables **multiple service instances** with shared queues

3. **Retry Count**: `"10"`
   - Number of **retry attempts** for failed event processing
   - Implements **resilience** against transient failures

### Real-World Event Flow Example

#### Business Scenario: Product Price Change

```csharp
// 1. Catalog Service publishes an event (Business Logic)
public class CatalogService
{
    private readonly IEventBus _eventBus;
    
    public async Task UpdateProductPrice(int productId, decimal newPrice)
    {
        // Update database
        await _catalogRepository.UpdatePriceAsync(productId, newPrice);
        
        // Publish business event
        var priceChangedEvent = new ProductPriceChangedEvent
        {
            ProductId = productId,
            NewPrice = newPrice,
            ChangedAt = DateTime.UtcNow
        };
        
        await _eventBus.PublishAsync(priceChangedEvent);
    }
}
```

#### Event Processing Pipeline:

1. **EventBus Layer** (Application):
   ```csharp
   // Serializes event to JSON
   // Adds metadata (event type, correlation ID, timestamp)
   // Determines routing key based on event type
   ```

2. **RabbitMQ Layer** (Infrastructure):
   ```
   Exchange: "eShop.Events"
   RoutingKey: "catalog.product.price.changed"
   Queue: "ordering-service-queue"
   Message: {"ProductId": 123, "NewPrice": 89.99, "ChangedAt": "2024-01-15T10:30:00Z"}
   ```

3. **Subscriber Services React**:
   ```csharp
   // Order Service - Updates pending order calculations
   // Inventory Service - Triggers restock alerts for price drops
   // Notification Service - Sends price change notifications to customers
   // Analytics Service - Records price change for business intelligence
   ```

### EventBus vs Direct HTTP Communication

| **EventBus Pattern** | **Direct HTTP Calls** |
|---------------------|----------------------|
| ✅ **Asynchronous** - Non-blocking | ❌ **Synchronous** - Blocking calls |
| ✅ **Decoupled** - Services don't know about each other | ❌ **Coupled** - Services must know endpoints |
| ✅ **Resilient** - Messages persist if service is down | ❌ **Fragile** - Calls fail if service unavailable |
| ✅ **Scalable** - Multiple subscribers can process | ❌ **Limited** - Point-to-point communication |
| ✅ **Auditable** - Message history and tracing | ❌ **Transient** - No natural audit trail |
| ❌ **Complex** - Requires message infrastructure | ✅ **Simple** - Direct communication |
| ❌ **Eventually Consistent** - Eventual propagation | ✅ **Strongly Consistent** - Immediate results |

### EventBus in ServiceDefaults

The EventBus is configured through ServiceDefaults for consistent behavior:

```csharp
// eShop.ServiceDefaults/Extensions.cs
public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder)
{
    builder.AddBasicServiceDefaults();
    
    // Configure HTTP clients for external service calls
    builder.Services.ConfigureHttpClientDefaults(http =>
    {
        http.AddStandardResilienceHandler();  // Polly retry policies
        http.AddServiceDiscovery();          // Service name resolution
    });
    
    // EventBus would be configured here in a real implementation
    // builder.AddEventBus(); // Adds RabbitMQ-based EventBus
    
    return builder;
}
```

### Message Patterns Supported

1. **Publish/Subscribe**: One publisher, multiple subscribers
   - `ProductPriceChangedEvent` → Multiple services react

2. **Request/Response**: Asynchronous request-reply pattern  
   - `GetInventoryStatusRequest` → `InventoryStatusResponse`

3. **Event Sourcing**: Events as the source of truth
   - All business state changes captured as events

4. **Saga Pattern**: Long-running business transactions
   - Order processing across multiple services

### Production Benefits

1. **Fault Tolerance**: Messages survive service restarts
2. **Load Balancing**: Multiple service instances share message processing
3. **Monitoring**: Built-in message tracking and dead letter queues
4. **Scaling**: Add subscribers without changing publishers
5. **Testing**: Easy to mock EventBus for unit tests
6. **Deployment**: Services can be deployed independently

### Key Insight: Separation of Concerns

The **EventBus abstraction** allows you to:
- **Swap transport mechanisms** (RabbitMQ → Azure Service Bus → Apache Kafka)
- **Change without breaking business logic**
- **Test business logic** independently of message infrastructure
- **Maintain consistent APIs** across different environments

This pattern is essential for **cloud-native microservices** where services must be **loosely coupled**, **independently deployable**, and **resilient to failures**.

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