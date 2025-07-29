# Kubernetes Deployment Explanation for .NET Microservices

This document explains how to deploy .NET microservices to Kubernetes with DevOps-friendly patterns, focusing on externalized configuration, service discovery via environment variables, and Helm chart management.

## Table of Contents
1. [Configuration Consistency: Aspire vs Production](#configuration-consistency-aspire-vs-production)
2. [DevOps-Friendly Service Discovery](#devops-friendly-service-discovery)
3. [Environment Variable Based Configuration](#environment-variable-based-configuration)
4. [Helm Chart Structure for Microservices](#helm-chart-structure-for-microservices)
5. [Complete Kubernetes Deployment Example](#complete-kubernetes-deployment-example)
6. [Service Naming and Versioning Strategy](#service-naming-and-versioning-strategy)
7. [Pure .NET Deployment Comparison](#pure-net-deployment-comparison)
8. [What Kubernetes Adds: The Value Proposition](#what-kubernetes-adds-the-value-proposition)

## Configuration Consistency: Aspire vs Production

### The Challenge: Configuration Drift

A critical DevOps challenge is ensuring **configuration consistency** between:
- **Local Development** (Aspire orchestration)  
- **Production Deployment** (Helm charts + Kubernetes)

**Common Problems:**
- Aspire uses different RabbitMQ configuration than production Helm chart
- Infrastructure service versions drift between environments
- Connection strings, ports, and settings differ
- Developers test against different setup than production

### Component Classification: Aspire-Specific vs Production-Ready

| Component | Type | Aspire Dependency | Production Use |
|-----------|------|------------------|----------------|
| **`eShop.ServiceDefaults`** | ✅ Production Ready | None | Use directly in production |
| **`EventBus`** | ✅ Production Ready | None | Use directly in production |
| **`EventBusRabbitMQ`** | ⚠️ Hybrid | `Aspire.RabbitMQ.Client` | Needs configuration mapping |
| **`eShop.AppHost`** | ❌ Development Only | Full Aspire | Never deploy to production |

### Configuration Extraction Strategy

#### 1. Extract Infrastructure Configuration from Aspire

**Aspire Configuration (AppHost/Program.cs):**
```csharp
// What Aspire sets up locally
var rabbitMq = builder.AddRabbitMQ("eventbus")
    .WithLifetime(ContainerLifetime.Persistent);
    
var postgres = builder.AddPostgres("postgres")
    .WithImage("ankane/pgvector")
    .WithImageTag("latest")
    .WithLifetime(ContainerLifetime.Persistent);

var redis = builder.AddRedis("redis");
```

**Extract for Helm Chart:**
```yaml
# values.yaml - Mirror Aspire configuration
global:
  infrastructure:
    rabbitmq:
      image: "rabbitmq:3-management"  # Match Aspire version
      serviceName: "rabbitmq-service"
      port: 5672
      managementPort: 15672
      config:
        # Extract from Aspire's default configuration
        RABBITMQ_DEFAULT_USER: "guest"
        RABBITMQ_VM_MEMORY_HIGH_WATERMARK: "0.6"
        
    postgres:
      image: "ankane/pgvector"
      tag: "latest"                   # Match Aspire exactly
      serviceName: "postgres-service"
      port: 5432
      databases:
        - catalogdb
        - identitydb
        - orderingdb
        - webhooksdb
        
    redis:
      image: "redis:7-alpine"         # Match Aspire version
      serviceName: "redis-service"
      port: 6379
```

#### 2. Application Configuration Consistency

**Aspire Injects (Development):**
```csharp
// AppHost automatically sets these
var basketApi = builder.AddProject<Projects.Basket_API>("basket-api")
    .WithReference(redis)
    .WithReference(rabbitMq)
    .WithEnvironment("Identity__Url", identityEndpoint);
```

**Helm Chart Equivalent (Production):**
```yaml
# ConfigMap - Mirror Aspire's injected configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: eshop-service-config
data:
  # Mirror Aspire's automatic service discovery
  ServiceEndpoints__IdentityApi: "http://identity-service"
  
  # Mirror Aspire's infrastructure references
  ConnectionStrings__Redis: "redis-service:6379"
  ConnectionStrings__EventBus: "amqp://rabbitmq-service:5672"
  
  # Mirror Aspire's EventBus configuration
  EventBus__SubscriptionClientName: "Basket"  # Must match Aspire
  EventBus__RetryCount: "10"                  # Must match Aspire
```

### RabbitMQ Configuration Consistency Example

#### Problem: Different RabbitMQ Setup

**Aspire (Local):**
```csharp
var rabbitMq = builder.AddRabbitMQ("eventbus")
    .WithLifetime(ContainerLifetime.Persistent);
// Uses default RabbitMQ configuration
```

**Helm Chart (Production) - Wrong Approach:**
```yaml
# This might use different configuration!
rabbitmq:
  image: "bitnami/rabbitmq:latest"  # Different image!
  auth:
    username: "admin"                # Different user!
    password: "CHANGEME"   # Different auth!
```

#### Solution: Configuration Extraction and Mapping

**Step 1: Document Aspire's Actual Configuration**
```yaml
# aspire-config-mapping.yaml - Document what Aspire actually uses
aspire:
  rabbitmq:
    image: "rabbitmq:3-management"
    ports:
      - "5672:5672"   # AMQP
      - "15672:15672" # Management UI
    environment:
      RABBITMQ_DEFAULT_USER: "guest"
      RABBITMQ_DEFAULT_PASS: "guest"
      RABBITMQ_VM_MEMORY_HIGH_WATERMARK: "0.6"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
```

**Step 2: Mirror in Helm Chart**
```yaml
# values.yaml
global:
  infrastructure:
    rabbitmq:
      # EXACTLY match Aspire configuration
      image: "rabbitmq:3-management"
      serviceName: "rabbitmq-service"
      auth:
        username: "guest"      # Match Aspire
        password: "guest"      # Match Aspire
      config:
        memoryHighWatermark: "0.6"  # Match Aspire
      persistence:
        enabled: true
        size: 8Gi
```

**Step 3: Validate Connection String Consistency**
```yaml
# Both environments must use same connection pattern
# Aspire generates: amqp://guest:guest@localhost:5672
# Production uses:  amqp://guest:guest@rabbitmq-service:5672
# Only the hostname differs!

# ConfigMap
ConnectionStrings__EventBus: "amqp://{{ .Values.global.infrastructure.rabbitmq.auth.username }}:{{ .Values.global.infrastructure.rabbitmq.auth.password }}@{{ .Values.global.infrastructure.rabbitmq.serviceName }}:5672"
```

### Infrastructure Version Consistency

#### Create Aspire Configuration Export

**Step 1: Add Configuration Documentation to AppHost**
```csharp
// AppHost/Infrastructure.cs - Document for DevOps
public static class InfrastructureConfig
{
    // Export configuration for Helm charts
    public static class Versions
    {
        public const string PostgreSQL = "ankane/pgvector:latest";
        public const string RabbitMQ = "rabbitmq:3-management";
        public const string Redis = "redis:7-alpine";
    }
    
    public static class Ports
    {
        public const int PostgreSQL = 5432;
        public const int RabbitMQ = 5672;
        public const int RabbitMQManagement = 15672;
        public const int Redis = 6379;
    }
}
```

**Step 2: Use in Both Aspire and Helm**
```csharp
// AppHost/Program.cs - Use constants
var postgres = builder.AddPostgres("postgres")
    .WithImage(InfrastructureConfig.Versions.PostgreSQL);
```

```yaml
# values.yaml - Import same constants
global:
  infrastructure:
    postgres:
      image: "ankane/pgvector"
      tag: "latest"
      port: 5432
```

### DevOps Workflow for Configuration Consistency

#### 1. Configuration Change Process
```bash
# When infrastructure configuration changes:
# 1. Update AppHost configuration
# 2. Export to Helm values
# 3. Test both environments
# 4. Deploy together

# Example: Upgrade RabbitMQ
git checkout feature/rabbitmq-upgrade
# Edit AppHost to use rabbitmq:3.12-management
# Edit values.yaml to use rabbitmq:3.12-management
# Test locally with Aspire
# Test staging with Helm
# Deploy to production
```

#### 2. Validation Scripts
```bash
# validate-config-consistency.sh
#!/bin/bash

# Extract Aspire configuration
aspire_rabbitmq_image=$(grep -o 'rabbitmq:[^"]*' src/eShop.AppHost/Program.cs)
aspire_postgres_image=$(grep -o 'ankane/pgvector:[^"]*' src/eShop.AppHost/Program.cs)

# Extract Helm configuration  
helm_rabbitmq_image=$(yq '.global.infrastructure.rabbitmq.image' helm/values.yaml)
helm_postgres_image=$(yq '.global.infrastructure.postgres.image' helm/values.yaml)

# Compare
if [[ "$aspire_rabbitmq_image" != "$helm_rabbitmq_image" ]]; then
  echo "ERROR: RabbitMQ image mismatch!"
  echo "Aspire: $aspire_rabbitmq_image"
  echo "Helm: $helm_rabbitmq_image"
  exit 1
fi

echo "✅ Configuration consistency validated"
```

## DevOps-Friendly Service Discovery

### The Problem with Hardcoded Service Names

**Bad Practice (Hardcoded in Application):**
```csharp
// This requires changing application code when service names change
builder.Services.AddHttpClient<CatalogService>(o => o.BaseAddress = new("http://catalog-api"))
    .AddApiVersion(2.0);
```

**DevOps Challenge:**
- Service names hardcoded in application code
- Changes require rebuilding containers
- No single source of truth for service naming
- Helm charts must match exact application expectations

### DevOps-Friendly Solution: Environment Variable Based Discovery

**Application Code (Environment Variable Driven):**
```csharp
// In WebApp/Extensions/Extensions.cs - DevOps Friendly Version
public static void AddApplicationServices(this IHostApplicationBuilder builder)
{
    // Get service endpoints from environment variables - DevOps controls these
    var catalogApiUrl = builder.Configuration["ServiceEndpoints:CatalogApi"] 
        ?? throw new InvalidOperationException("CatalogApi endpoint not configured");
    var basketApiUrl = builder.Configuration["ServiceEndpoints:BasketApi"] 
        ?? throw new InvalidOperationException("BasketApi endpoint not configured");
    var orderingApiUrl = builder.Configuration["ServiceEndpoints:OrderingApi"] 
        ?? throw new InvalidOperationException("OrderingApi endpoint not configured");
    var identityApiUrl = builder.Configuration["ServiceEndpoints:IdentityApi"] 
        ?? throw new InvalidOperationException("IdentityApi endpoint not configured");

    // Configure HTTP clients with environment-provided URLs
    builder.Services.AddHttpClient<CatalogService>(o => o.BaseAddress = new(catalogApiUrl))
        .AddApiVersion(2.0)
        .AddAuthToken();

    builder.Services.AddHttpClient<OrderingService>(o => o.BaseAddress = new(orderingApiUrl))
        .AddApiVersion(1.0)
        .AddAuthToken();

    builder.Services.AddGrpcClient<Basket.BasketClient>(o => o.Address = new(basketApiUrl))
        .AddAuthToken();
}
```

**Application Configuration (appsettings.json) - Fallback Only:**
```json
{
  "ServiceEndpoints": {
    "CatalogApi": "http://localhost:8080",
    "BasketApi": "http://localhost:8081", 
    "OrderingApi": "http://localhost:8082",
    "IdentityApi": "http://localhost:8083"
  }
}
```

## Environment Variable Based Configuration

### 1. Configuration Hierarchy for Service Discovery

.NET Configuration follows this priority order:
1. **Environment Variables** (Highest Priority - DevOps Controls)
2. **appsettings.{Environment}.json**
3. **appsettings.json** (Fallback for local development)

```bash
# Environment variables override everything
ServiceEndpoints__CatalogApi=http://catalog-service
ServiceEndpoints__BasketApi=http://basket-service
ServiceEndpoints__OrderingApi=http://ordering-service
ServiceEndpoints__IdentityApi=http://identity-service
```

### 2. Kubernetes ConfigMap with Environment Variables

```yaml
# ConfigMap - Single Source of Truth for Service Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: eshop-service-config
  namespace: eshop-production
data:
  # Service Discovery - DevOps Controls These Names
  ServiceEndpoints__CatalogApi: "http://catalog-service"
  ServiceEndpoints__BasketApi: "http://basket-service"
  ServiceEndpoints__OrderingApi: "http://ordering-service"
  ServiceEndpoints__IdentityApi: "http://identity-service"
  
  # Infrastructure Services
  ConnectionStrings__Redis: "redis-service:6379"
  ConnectionStrings__EventBus: "amqp://rabbitmq-service:5672"
  
  # Application Settings
  ASPNETCORE_ENVIRONMENT: "Production"
  Logging__LogLevel__Default: "Information"
  EventBus__SubscriptionClientName: "WebApp"

---
# Secrets for sensitive data
apiVersion: v1
kind: Secret
metadata:
  name: eshop-secrets
  namespace: eshop-production
type: Opaque
stringData:
  ConnectionStrings__CatalogDB: "Host=postgres-service;Database=catalogdb;Username=sa;Password=YourStrongPassword!"
  ConnectionStrings__IdentityDB: "Host=postgres-service;Database=identitydb;Username=sa;Password=YourStrongPassword!"
  ConnectionStrings__OrderingDB: "Host=postgres-service;Database=orderingdb;Username=sa;Password=YourStrongPassword!"
```

## Helm Chart Structure for Microservices

### 1. Parent Helm Chart Structure

```
eshop-microservices/
├── Chart.yaml
├── values.yaml                 # Global configuration
├── templates/
│   ├── _helpers.tpl           # Shared templates
│   ├── configmap.yaml         # Global config
│   ├── secrets.yaml           # Global secrets
│   └── ingress.yaml           # Global ingress
└── charts/                    # Subcharts for each service
    ├── catalog-api/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── deployment.yaml
    │       └── service.yaml
    ├── basket-api/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── deployment.yaml
    │       └── service.yaml
    ├── webapp/
    └── infrastructure/        # Redis, RabbitMQ, etc.
```

### 2. Global Values.yaml - Single Source of Truth

```yaml
# eshop-microservices/values.yaml
global:
  # Service Naming Convention - DevOps Controls
  serviceNames:
    catalogApi: "catalog-service"
    basketApi: "basket-service" 
    orderingApi: "ordering-service"
    identityApi: "identity-service"
    webapp: "webapp-service"
    
  # Infrastructure Services
  infrastructure:
    redis:
      serviceName: "redis-service"
      port: 6379
    rabbitmq:
      serviceName: "rabbitmq-service"
      port: 5672
    postgres:
      serviceName: "postgres-service"
      port: 5432
      
  # Container Registry
  imageRegistry: "ghcr.io/saadisfy/eshop"
  imageTag: "1.0.0"
  
  # Namespace
  namespace: "eshop-production"

# Service-specific configurations
catalogApi:
  enabled: true
  replicaCount: 3
  image:
    repository: catalog-api
    tag: "" # Uses global.imageTag if empty
  resources:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"

basketApi:
  enabled: true
  replicaCount: 3
  image:
    repository: basket-api
    tag: ""

webapp:
  enabled: true
  replicaCount: 2
  image:
    repository: webapp
    tag: ""
  # WebApp needs to know about all other services
  serviceEndpoints:
    catalog: true
    basket: true
    ordering: true
    identity: true
```

### 3. Service-Specific Helm Templates

**WebApp Deployment Template (`charts/webapp/templates/deployment.yaml`):**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.global.serviceNames.webapp }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .Values.webapp.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Values.global.serviceNames.webapp }}
  template:
    metadata:
      labels:
        app: {{ .Values.global.serviceNames.webapp }}
    spec:
      containers:
      - name: webapp
        image: "{{ .Values.global.imageRegistry }}/{{ .Values.webapp.image.repository }}:{{ .Values.webapp.image.tag | default .Values.global.imageTag }}"
        ports:
        - containerPort: 8080
        
        # Environment variables from global ConfigMap
        envFrom:
        - configMapRef:
            name: eshop-service-config
        
        # Service-specific environment variables
        env:
        {{- if .Values.webapp.serviceEndpoints.catalog }}
        - name: ServiceEndpoints__CatalogApi
          value: "http://{{ .Values.global.serviceNames.catalogApi }}"
        {{- end }}
        {{- if .Values.webapp.serviceEndpoints.basket }}
        - name: ServiceEndpoints__BasketApi
          value: "http://{{ .Values.global.serviceNames.basketApi }}"
        {{- end }}
        {{- if .Values.webapp.serviceEndpoints.ordering }}
        - name: ServiceEndpoints__OrderingApi
          value: "http://{{ .Values.global.serviceNames.orderingApi }}"
        {{- end }}
        {{- if .Values.webapp.serviceEndpoints.identity }}
        - name: ServiceEndpoints__IdentityApi
          value: "http://{{ .Values.global.serviceNames.identityApi }}"
        {{- end }}
        
        # Database connections from secrets
        - name: ConnectionStrings__CatalogDB
          valueFrom:
            secretKeyRef:
              name: eshop-secrets
              key: ConnectionStrings__CatalogDB
              
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /health  
            port: 8080
          initialDelaySeconds: 10
            
        resources:
          {{- toYaml .Values.webapp.resources | nindent 12 }}
```

**Service Template (`charts/webapp/templates/service.yaml`):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.global.serviceNames.webapp }}
  namespace: {{ .Values.global.namespace }}
spec:
  selector:
    app: {{ .Values.global.serviceNames.webapp }}
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  type: ClusterIP
```

## Service Naming and Versioning Strategy

### 1. Single Source of Truth Pattern

**Problem:** Service names scattered across:
- Application code
- Kubernetes manifests  
- Helm values
- ConfigMaps

**Solution:** Centralized naming in Helm values:

```yaml
# values.yaml - SINGLE SOURCE OF TRUTH
global:
  serviceNames:
    # Logical name -> Kubernetes service name mapping
    catalogApi: "catalog-service-v2"    # Change here to update everywhere
    basketApi: "basket-service"
    orderingApi: "ordering-service-v1"
    identityApi: "identity-service"
```

### 2. Helm Helper Templates for Consistency

**`templates/_helpers.tpl`:**
```yaml
{{/*
Generate service endpoint URL
*/}}
{{- define "eshop.serviceUrl" -}}
{{- $serviceName := index .Values.global.serviceNames .serviceName -}}
http://{{ $serviceName }}
{{- end }}

{{/*
Generate full image name
*/}}
{{- define "eshop.image" -}}
{{ .Values.global.imageRegistry }}/{{ .image.repository }}:{{ .image.tag | default .Values.global.imageTag }}
{{- end }}
```

**Usage in Templates:**
```yaml
env:
- name: ServiceEndpoints__CatalogApi
  value: {{ include "eshop.serviceUrl" (dict "Values" .Values "serviceName" "catalogApi") }}
- name: ServiceEndpoints__BasketApi  
  value: {{ include "eshop.serviceUrl" (dict "Values" .Values "serviceName" "basketApi") }}
```

### 3. Version Management Strategy

**Microservice Versioning in Helm:**
```yaml
# values.yaml
global:
  imageTag: "1.2.0"  # Default version for all services
  
# Override specific service versions
catalogApi:
  image:
    tag: "1.3.0"  # Catalog API uses newer version

basketApi:
  image:
    tag: "1.1.5"  # Basket API uses older stable version
```

**Service Name Versioning:**
```yaml
global:
  serviceNames:
    # Include version in service name for breaking changes
    catalogApi: "catalog-service-v2" 
    basketApi: "basket-service-v1"
    # Or use blue-green deployment pattern
    catalogApiBlue: "catalog-service-blue"
    catalogApiGreen: "catalog-service-green"
```

## Complete Kubernetes Deployment Example

### 1. Infrastructure Services

**Postgres StatefulSet:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: {{ .Values.global.namespace }}
spec:
  serviceName: {{ .Values.global.infrastructure.postgres.serviceName }}
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: ankane/pgvector:latest
        ports:
        - containerPort: {{ .Values.global.infrastructure.postgres.port }}
        env:
        - name: POSTGRES_DB
          value: eShopDB
        - name: POSTGRES_USER
          value: sa
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: eshop-secrets
              key: postgres-password
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi

---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.global.infrastructure.postgres.serviceName }}
  namespace: {{ .Values.global.namespace }}
spec:
  selector:
    app: postgres
  ports:
    - port: {{ .Values.global.infrastructure.postgres.port }}
      targetPort: {{ .Values.global.infrastructure.postgres.port }}
  type: ClusterIP
```

### 2. Microservice Deployment with Environment Variables

**Catalog API Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.global.serviceNames.catalogApi }}
  namespace: {{ .Values.global.namespace }}
spec:
  replicas: {{ .Values.catalogApi.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Values.global.serviceNames.catalogApi }}
  template:
    metadata:
      labels:
        app: {{ .Values.global.serviceNames.catalogApi }}
    spec:
      containers:
      - name: catalog-api
        image: "{{ .Values.global.imageRegistry }}/{{ .Values.catalogApi.image.repository }}:{{ .Values.catalogApi.image.tag | default .Values.global.imageTag }}"
        ports:
        - containerPort: 8080
        
        # Global configuration from ConfigMap
        envFrom:
        - configMapRef:
            name: eshop-service-config
            
        # Service-specific configuration
        env:
        - name: ConnectionStrings__CatalogDB
          valueFrom:
            secretKeyRef:
              name: eshop-secrets
              key: ConnectionStrings__CatalogDB
        - name: ConnectionStrings__EventBus
          value: "amqp://{{ .Values.global.infrastructure.rabbitmq.serviceName }}:{{ .Values.global.infrastructure.rabbitmq.port }}"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
            
        resources:
          {{- toYaml .Values.catalogApi.resources | nindent 12 }}
```

### 3. Deployment Commands

**Deploy with Helm:**
```bash
# Install/upgrade entire application
helm upgrade --install eshop ./eshop-microservices \
  --namespace eshop-production \
  --create-namespace \
  --values values.yaml

# Override specific values for different environments
helm upgrade --install eshop ./eshop-microservices \
  --namespace eshop-staging \
  --set global.imageTag=1.3.0-beta \
  --set catalogApi.replicaCount=1 \
  --set global.serviceNames.catalogApi=catalog-service-beta
```

**Update Service Names Without Code Changes:**
```bash
# Change service names in production
helm upgrade eshop ./eshop-microservices \
  --set global.serviceNames.catalogApi=catalog-service-v2 \
  --set global.serviceNames.basketApi=basket-service-new
```

## Pure .NET Deployment Comparison

### Traditional Deployment Challenges

**Manual Configuration Management:**
```json
// On each server, manually configure appsettings.Production.json
{
  "ServiceEndpoints": {
    "CatalogApi": "http://server3.company.com:8080",
    "BasketApi": "http://server4.company.com:8080", 
    "OrderingApi": "http://server5.company.com:8080"
  }
}
```

**Problems:**
- Each server needs individual configuration
- No centralized configuration management
- Service discovery requires manual IP/hostname management
- Load balancing requires external tools
- Scaling requires manual server provisioning

## What Kubernetes Adds: The Value Proposition

### Configuration Management Comparison

| Aspect | Pure .NET | Kubernetes + Helm |
|--------|-----------|-------------------|
| **Service Names** | Hardcoded in each service config | Centralized in Helm values |
| **Configuration Updates** | Restart all services manually | Rolling updates automatically |
| **Environment Consistency** | Manual synchronization | Declarative templates |
| **Service Discovery** | Static IP configuration | Dynamic DNS resolution |
| **Scaling** | Manual server provisioning | Horizontal pod autoscaling |
| **Version Management** | Individual deployment tracking | Helm release management |

### DevOps Benefits Summary

**Single Source of Truth:**
```yaml
# Change service name once, affects all dependencies
global:
  serviceNames:
    catalogApi: "catalog-service-v2"  # Updates everywhere automatically
```

**Environment Promotion:**
```bash
# Same chart, different values per environment
helm install eshop-dev ./eshop --values values-dev.yaml
helm install eshop-staging ./eshop --values values-staging.yaml  
helm install eshop-prod ./eshop --values values-prod.yaml
```

**Blue-Green Deployments:**
```yaml
# Switch traffic between versions
global:
  serviceNames:
    catalogApi: "catalog-service-blue"  # or "catalog-service-green"
```

This approach gives you complete DevOps control over service naming and configuration without requiring application code changes - exactly what you need for professional microservices management! 