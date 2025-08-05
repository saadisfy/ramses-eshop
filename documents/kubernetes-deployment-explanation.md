# eShop Kubernetes Deployment Architecture

This document explains the complete Kubernetes deployment architecture for the eShop .NET microservices application, including Helm chart structure, shared infrastructure patterns, and DevOps-friendly service discovery.

## Table of Contents
1. [eShop Microservices Architecture Overview](#eshop-microservices-architecture-overview)
2. [Helm Chart Structure and Dependencies](#helm-chart-structure-and-dependencies)
3. [Shared Infrastructure Pattern](#shared-infrastructure-pattern)
4. [BaseChart Reusability Pattern](#basechart-reusability-pattern)
5. [Service-Specific Configurations](#service-specific-configurations)
6. [Deployment Architecture](#deployment-architecture)
7. [Configuration Management](#configuration-management)
8. [DevOps Deployment Workflow](#devops-deployment-workflow)
9. [Service Discovery and Networking](#service-discovery-and-networking)
10. [Production Deployment Guide](#production-deployment-guide)

## eShop Microservices Architecture Overview

### Complete Service Landscape

The eShop application consists of **10 microservices** deployed using a **shared infrastructure pattern** in Kubernetes:

| Service | Database | EventBus | Ingress | Purpose |
|---------|----------|----------|---------|---------|
| **`rabbitmq`** | ❌ | ✅ **(Provides)** | ❌ | Shared EventBus for all microservices |
| **`identity-api`** | PostgreSQL | ✅ | ✅ | Authentication & authorization |
| **`catalog-api-v2`** | PostgreSQL (pgvector) | ✅ | ✅ | Product catalog with AI features |
| **`ordering-api`** | PostgreSQL | ✅ | ✅ | Order management |
| **`order-processor`** | PostgreSQL | ✅ | ❌ | Background order processing |
| **`basket-api`** | Redis | ✅ | ✅ | Shopping cart management |
| **`payment-processor`** | ❌ | ✅ | ❌ | Background payment processing |
| **`webhooks-api`** | PostgreSQL | ❌ | ✅ | Webhook management |
| **`webhook-client`** | ❌ | ❌ | ✅ | Webhook testing client |
| **`webapp`** | ❌ | ✅ | ✅ | Frontend application |

### Key Architectural Decisions

1. **Shared EventBus**: Single RabbitMQ deployment serves all microservices that need messaging
2. **Database Isolation**: Each service requiring a database gets its own PostgreSQL instance  
3. **Specialized Storage**: `basket-api` uses Redis for performance; `catalog-api-v2` uses pgvector for AI
4. **Reusable Base**: All services use a common `basechart` for consistency and maintainability
5. **Service Separation**: Background processors (`order-processor`, `payment-processor`) run without ingress

## Helm Chart Structure and Dependencies

### Chart Organization

```
helm/charts/
├── basechart/                 # Reusable base chart (published to GHCR)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl       # Shared template functions
│       ├── deployment.yaml    # Application deployment
│       ├── service.yaml       # Kubernetes service
│       ├── ingress.yaml       # External access (conditional)
│       ├── postgresql.yaml    # Database (conditional)
│       └── serviceaccount.yaml # Service account (conditional)
│
├── rabbitmq/                  # Shared EventBus infrastructure
│   ├── Chart.yaml
│   └── values.yaml
│
├── identity-api/              # Individual microservice charts
├── catalog-api-v2/
├── ordering-api/
├── order-processor/
├── basket-api/
├── payment-processor/
├── webhooks-api/
├── webhook-client/
└── webapp/
```

### BaseChart Dependency Pattern

All microservice charts follow the same dependency structure:

```yaml
# Example: helm/charts/identity-api/Chart.yaml
apiVersion: v2
name: identity-api
version: 0.1.0
description: eShop Identity API microservice using basechart dependency
type: application
appVersion: "1.0.0"
dependencies:
  - name: basechart
    version: "1.0.0"
    repository: "oci://ghcr.io/saadisfy"
    alias: base
```

## Shared Infrastructure Pattern

### RabbitMQ as Shared EventBus

The eShop architecture uses a **single, shared RabbitMQ deployment** that serves as the EventBus for all microservices requiring message-based communication.

#### Standalone RabbitMQ Chart

```yaml
# helm/charts/rabbitmq/Chart.yaml
apiVersion: v2
name: rabbitmq
version: 1.0.0
description: Shared RabbitMQ EventBus for eShop microservices
type: application
appVersion: "3.13.6"
dependencies:
  - name: rabbitmq
    version: "14.6.6"
    repository: "https://charts.bitnami.com/bitnami"
```

```yaml
# helm/charts/rabbitmq/values.yaml
rabbitmq:
  # Authentication settings
  auth:
    username: "user"
    password: "CHANGEME"
    erlangCookie: "CHANGEME"
  
  # Service configuration
  service:
    ports:
      amqp: 5672  # AMQP (Advanced Message Queuing Protocol)
  
  # Persistence and resources
  persistence:
    enabled: true
    size: 8Gi
  resources:
    limits:
      cpu: 375m
      memory: 384Mi
    requests:
      cpu: 250m
      memory: 256Mi
```

### Services Using Shared EventBus

The following services connect to the shared RabbitMQ deployment:

- **`identity-api`** - Subscription: "Identity"
- **`catalog-api-v2`** - Subscription: "Catalog" 
- **`ordering-api`** - Subscription: "Ordering"
- **`order-processor`** - Subscription: "OrderProcessor"
- **`basket-api`** - Subscription: "Basket"
- **`payment-processor`** - Subscription: "Payment"
- **`webapp`** - Subscription: "WebApp"

### Database Isolation Strategy

Each service requiring a database gets its **own PostgreSQL instance**:

```yaml
# Example database configuration per service
postgresql:
  enabled: true
  serviceName: ""  # Defaults to: {{ .Release.Name }}-postgresql
  auth:
    database: "identitydb"      # Service-specific database name
    username: "postgres"
    password: "CHANGEME"  # Service-specific password
```

## BaseChart Reusability Pattern

### Generic Base Chart Design

The `basechart` provides a **reusable foundation** for all eShop microservices, with conditional components that can be enabled/disabled per service:

```yaml
# helm/charts/basechart/values.yaml (key sections)
# Application configuration
application:
  name: "my-application"

# Image configuration
image:
  registry: "ghcr.io/saadisfy/eshop"
  repository: "my-service"
  tag: "1.0.0"
  pullPolicy: IfNotPresent
  pullSecret: "ghcr-secret"

# Conditional PostgreSQL
postgresql:
  enabled: false  # Enable per service
  auth:
    database: "mydb"
    username: "postgres"
    password: "CHANGEME"

# Conditional Redis  
redis:
  enabled: false  # Enable per service

# External services configuration
sharedServices:
  rabbitmq:
    enabled: false  # Enable per service
    serviceName: ""  # Auto-resolved
    port: 5672
    username: "user"
    password: "CHANGEME"
    subscriptionClientName: "DefaultClient"
```

### Service-Specific Overrides

Each microservice chart overrides only the necessary values:

```yaml
# helm/charts/identity-api/values.yaml
base:
  application:
    name: "identity-api"
  
  image:
    repository: "identity-api"
  
  # Enable PostgreSQL for this service
  postgresql:
    enabled: true
    auth:
      database: "identitydb"
      password: "CHANGEME"
  
  # Enable EventBus for this service
  sharedServices:
    rabbitmq:
      enabled: true
      subscriptionClientName: "Identity"
  
  # Service-specific configuration
  config:
    appSettings:
      Identity__Issuer: "https://identity-api.saadisfy.me"
```

## Service-Specific Configurations

### Complete Service Configuration Matrix

| Service | PostgreSQL DB | Redis | EventBus | Ingress | Special Features |
|---------|---------------|--------|----------|---------|------------------|
| **identity-api** | `identitydb` | ❌ | Identity | ✅ | JWT issuer |
| **catalog-api-v2** | `catalogdb` (pgvector) | ❌ | Catalog | ✅ | AI/Vector search |
| **ordering-api** | `orderingdb` | ❌ | Ordering | ✅ | Order management |
| **order-processor** | `orderprocessordb` | ❌ | OrderProcessor | ❌ | Background worker |
| **basket-api** | ❌ | ✅ | Basket | ✅ | Redis cache |
| **payment-processor** | ❌ | ❌ | Payment | ❌ | Background worker |
| **webhooks-api** | `webhooksdb` | ❌ | ❌ | ✅ | No EventBus |
| **webhook-client** | ❌ | ❌ | ❌ | ✅ | Direct HTTP |
| **webapp** | ❌ | ❌ | WebApp | ✅ | Frontend |

### Example Configurations

#### Full-Stack Service (PostgreSQL + EventBus + Ingress)
```yaml
# identity-api/values.yaml
base:
  postgresql:
    enabled: true
    auth:
      database: "identitydb"
      password: "CHANGEME"
  
  sharedServices:
    rabbitmq:
      enabled: true
      subscriptionClientName: "Identity"
  
  ingress:
    enabled: true
    hosts:
      - host: "identity-api.saadisfy.me"
```

#### Background Worker (PostgreSQL + EventBus, No Ingress)
```yaml
# order-processor/values.yaml  
base:
  postgresql:
    enabled: true
    auth:
      database: "orderprocessordb"
      password: "CHANGEME"
  
  sharedServices:
    rabbitmq:
      enabled: true
      subscriptionClientName: "OrderProcessor"
  
  ingress:
    enabled: false  # Background service
  
  livenessProbe:
    enabled: false  # No HTTP endpoints
```

#### Cache-Based Service (Redis + EventBus + Ingress)
```yaml
# basket-api/values.yaml
base:
  postgresql:
    enabled: false  # Uses Redis instead
  
  redis:
    enabled: true
    serviceName: ""  # Defaults to {{ .Release.Name }}-redis
    port: 6379
  
  sharedServices:
    rabbitmq:
      enabled: true
      subscriptionClientName: "Basket"
```

## Deployment Architecture

### Physical Deployment Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                          │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │    Frontend     │    │   API Gateway   │    │ Background  │ │
│  │   (Ingress)     │    │   (Ingress)     │    │ Workers     │ │
│  │                 │    │                 │    │             │ │
│  │ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────┐ │ │
│  │ │   webapp    │ │    │ │identity-api │ │    │ │order-   │ │ │
│  │ └─────────────┘ │    │ │catalog-api  │ │    │ │processor│ │ │
│  │                 │    │ │ordering-api │ │    │ │payment- │ │ │
│  │ ┌─────────────┐ │    │ │basket-api   │ │    │ │processor│ │ │
│  │ │webhook-     │ │    │ │webhooks-api │ │    │ └─────────┘ │ │
│  │ │client       │ │    │ └─────────────┘ │    └─────────────┘ │
│  │ └─────────────┘ │    └─────────────────┘                    │
│  └─────────────────┘                                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                Shared Infrastructure                        │ │
│  │                                                             │ │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │ │
│  │  │  RabbitMQ   │ │PostgreSQL   │ │    Redis    │           │ │
│  │  │ (EventBus)  │ │(per service)│ │(basket-api) │           │ │
│  │  │             │ │             │ │             │           │ │
│  │  │ Port: 5672  │ │ Port: 5432  │ │ Port: 6379  │           │ │
│  │  └─────────────┘ └─────────────┘ └─────────────┘           │ │
│  └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Service Communication Patterns

#### 1. EventBus Communication (Asynchronous)
```
identity-api ──┐
catalog-api ───┤
ordering-api ──┤── EventBus (RabbitMQ) ──┤── order-processor
basket-api ────┤                         ├── payment-processor  
webapp ────────┘                         └── [other subscribers]
```

#### 2. Direct HTTP Communication (Synchronous)
```
webapp ── HTTP ──→ identity-api (auth)
webapp ── HTTP ──→ catalog-api (products)
webapp ── HTTP ──→ ordering-api (orders)
webapp ── HTTP ──→ basket-api (cart)

webhook-client ── HTTP ──→ webhooks-api
```

#### 3. Database Access Patterns
```
identity-api ──→ PostgreSQL (identitydb)
catalog-api ───→ PostgreSQL (catalogdb + pgvector)
ordering-api ──→ PostgreSQL (orderingdb)
order-processor → PostgreSQL (orderprocessordb)
webhooks-api ──→ PostgreSQL (webhooksdb)

basket-api ────→ Redis (cache)
```

## DevOps Deployment Workflow

### Deployment Order and Dependencies

#### 1. Infrastructure First (Shared Services)
```bash
# Deploy shared EventBus first
helm install rabbitmq helm/charts/rabbitmq \
  --namespace eshop-production \
  --create-namespace

# Verify RabbitMQ is ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=rabbitmq \
  --namespace eshop-production --timeout=300s
```

#### 2. Core Services (With Dependencies)
```bash
# Deploy services with databases and EventBus
helm install identity-api helm/charts/identity-api \
  --namespace eshop-production

helm install catalog-api helm/charts/catalog-api-v2 \
  --namespace eshop-production

helm install ordering-api helm/charts/ordering-api \
  --namespace eshop-production

# Background processors
helm install order-processor helm/charts/order-processor \
  --namespace eshop-production

helm install payment-processor helm/charts/payment-processor \
  --namespace eshop-production
```

#### 3. Specialized Services
```bash
# Redis-based service
helm install basket-api helm/charts/basket-api \
  --namespace eshop-production

# Independent services (no EventBus)
helm install webhooks-api helm/charts/webhooks-api \
  --namespace eshop-production

helm install webhook-client helm/charts/webhook-client \
  --namespace eshop-production
```

#### 4. Frontend Last
```bash
# Deploy frontend after all APIs are ready
helm install webapp helm/charts/webapp \
  --namespace eshop-production
```

### Environment-Specific Deployment

#### Development Environment
```bash
# Use local development values
helm install eshop-dev helm/charts/identity-api \
  --namespace eshop-dev \
  --set base.image.tag=dev-latest \
  --set base.ingress.hosts[0].host=identity-api-dev.local \
  --set base.postgresql.auth.password=devpassword
```

#### Staging Environment
```bash
# Use staging-specific configuration
helm install eshop-staging helm/charts/identity-api \
  --namespace eshop-staging \
  --set base.image.tag=1.0.0-rc1 \
  --set base.ingress.hosts[0].host=identity-api-staging.saadisfy.me \
  --set base.resources.requests.cpu=100m
```

#### Production Environment
```bash
# Use production configuration with high availability
helm install eshop-prod helm/charts/identity-api \
  --namespace eshop-production \
  --set base.image.tag=1.0.0 \
  --set base.replicaCount=3 \
  --set base.resources.requests.cpu=250m \
  --set base.resources.limits.cpu=500m
```

## Configuration Management

### Environment Variable Based Configuration

All eShop services use **environment variables** for configuration, allowing DevOps teams to control service behavior without rebuilding containers.

#### BaseChart Configuration Template

```yaml
# basechart/templates/deployment.yaml
env:
# Database connections (if enabled)
{{- if .Values.postgresql.enabled }}
- name: ConnectionStrings__{{ .Values.postgresql.auth.database }}
  value: {{ include "application.postgresqlConnectionString" . }}
{{- end }}

{{- if .Values.redis.enabled }}
- name: ConnectionStrings__Redis
  value: "{{ .Values.redis.serviceName | default (printf "%s-redis" .Release.Name) }}:{{ .Values.redis.port }}"
{{- end }}

# EventBus configuration (if enabled)
{{- if .Values.sharedServices.rabbitmq.enabled }}
- name: EventBus__Connection
  value: "amqp://{{ .Values.sharedServices.rabbitmq.serviceName | default (printf "%s-rabbitmq" .Release.Name) }}:{{ .Values.sharedServices.rabbitmq.port }}"
- name: EventBus__UserName
  value: {{ .Values.sharedServices.rabbitmq.username }}
- name: EventBus__Password
  value: {{ .Values.sharedServices.rabbitmq.password }}
- name: EventBus__SubscriptionClientName
  value: {{ .Values.sharedServices.rabbitmq.subscriptionClientName }}
{{- end }}

# Custom application settings
{{- range $key, $value := .Values.config.appSettings }}
- name: {{ $key }}
  value: {{ $value | quote }}
{{- end }}
```

#### Service Name Resolution

Services connect to shared infrastructure using **dynamic service name resolution**:

```yaml
# Each service connects to shared RabbitMQ
sharedServices:
  rabbitmq:
    serviceName: ""  # Empty = auto-resolve to shared RabbitMQ
    # Resolves to: external rabbitmq service discovery
```

## Service Discovery and Networking

### Kubernetes-Native Service Discovery

Services discover each other using **Kubernetes DNS**:

```yaml
# webapp communicates with APIs via service names
config:
  appSettings:
    # Service endpoints resolve via Kubernetes DNS
    IdentityApiClient: "http://identity-api-identity-api"
    CatalogApiClient: "http://catalog-api-catalog-api-v2" 
    OrderingApiClient: "http://ordering-api-ordering-api"
    BasketApiClient: "http://basket-api-basket-api"
```

### External Access via Ingress

```yaml
# Each API service gets external access
ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: "identity-api.saadisfy.me"
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: "identity-api-tls"
      hosts:
        - "identity-api.saadisfy.me"
```

## Production Deployment Guide

### Complete Production Deployment Script

```bash
#!/bin/bash
# deploy-eshop-production.sh

set -e

NAMESPACE="eshop-production"
echo "🚀 Deploying eShop to $NAMESPACE"

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 1. Deploy shared infrastructure first
echo "📦 Deploying shared RabbitMQ..."
helm upgrade --install rabbitmq helm/charts/rabbitmq \
  --namespace $NAMESPACE \
  --wait --timeout=10m

# 2. Deploy core services with databases
echo "🔐 Deploying Identity API..."
helm upgrade --install identity-api helm/charts/identity-api \
  --namespace $NAMESPACE \
  --wait --timeout=10m

echo "📋 Deploying Catalog API..."
helm upgrade --install catalog-api helm/charts/catalog-api-v2 \
  --namespace $NAMESPACE \
  --wait --timeout=10m

echo "📦 Deploying Ordering API..."
helm upgrade --install ordering-api helm/charts/ordering-api \
  --namespace $NAMESPACE \
  --wait --timeout=10m

echo "🛒 Deploying Basket API..."
helm upgrade --install basket-api helm/charts/basket-api \
  --namespace $NAMESPACE \
  --wait --timeout=10m

# 3. Deploy background processors
echo "⚙️ Deploying Order Processor..."
helm upgrade --install order-processor helm/charts/order-processor \
  --namespace $NAMESPACE \
  --wait --timeout=10m

echo "💳 Deploying Payment Processor..."
helm upgrade --install payment-processor helm/charts/payment-processor \
  --namespace $NAMESPACE \
  --wait --timeout=10m

# 4. Deploy webhook services
echo "🪝 Deploying Webhooks API..."
helm upgrade --install webhooks-api helm/charts/webhooks-api \
  --namespace $NAMESPACE \
  --wait --timeout=10m

echo "🔗 Deploying Webhook Client..."
helm upgrade --install webhook-client helm/charts/webhook-client \
  --namespace $NAMESPACE \
  --wait --timeout=10m

# 5. Deploy frontend last
echo "🌐 Deploying WebApp..."
helm upgrade --install webapp helm/charts/webapp \
  --namespace $NAMESPACE \
  --wait --timeout=10m

echo "✅ eShop deployment complete!"
echo "🌍 Access the application at: https://webapp.saadisfy.me"
```

### Monitoring and Verification

```bash
# Check all deployments
kubectl get deployments -n eshop-production

# Check all services
kubectl get services -n eshop-production

# Check ingress endpoints
kubectl get ingress -n eshop-production

# View logs for troubleshooting
kubectl logs -l app.kubernetes.io/name=identity-api -n eshop-production
kubectl logs -l app.kubernetes.io/name=catalog-api -n eshop-production

# Check RabbitMQ management UI
kubectl port-forward svc/rabbitmq 15672:15672 -n eshop-production
# Access: http://localhost:15672 (user/password)
```

### Rolling Updates and Versioning

```bash
# Update specific service to new version
helm upgrade identity-api helm/charts/identity-api \
  --namespace eshop-production \
  --set base.image.tag=1.1.0 \
  --wait

# Rollback if needed
helm rollback identity-api 1 --namespace eshop-production

# Update multiple services
for service in identity-api catalog-api ordering-api basket-api; do
  helm upgrade $service helm/charts/$service \
    --namespace eshop-production \
    --set base.image.tag=1.1.0 \
    --wait
done
```

### High Availability Configuration

```yaml
# production-values.yaml
base:
  replicaCount: 3
  
  resources:
    requests:
      cpu: 250m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  
  postgresql:
    persistence:
      enabled: true
      size: 20Gi
      storageClass: "fast-ssd"
  
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
```

### Security Considerations

```yaml
# Secure production configuration
base:
  serviceAccount:
    create: true
    annotations:
      # AWS IAM role annotation
      eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/eShopServiceRole
  
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 1001
    fsGroup: 1001
  
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL
```

---

## 🏆 **Architecture Summary**

The eShop Kubernetes deployment provides:

✅ **Shared Infrastructure**: Single RabbitMQ for all messaging  
✅ **Database Isolation**: Each service has dedicated storage  
✅ **Reusable Patterns**: BaseChart eliminates duplication  
✅ **Environment Flexibility**: Same charts, different configurations  
✅ **Production Ready**: Security, scaling, monitoring included  
✅ **DevOps Friendly**: Environment variable driven configuration  

This architecture ensures **scalable**, **maintainable**, and **production-ready** deployment of the complete eShop microservices application! 🎯

 