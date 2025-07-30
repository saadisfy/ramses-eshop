# eShop Microservice Base Helm Chart

This is a base Helm chart template designed for deploying eShop microservices on Kubernetes. It provides a standardized, configurable deployment pattern that can be used for any eShop microservice by simply changing the `values.yaml` file.

## Features

- **Environment Variable-Based Service Discovery**: Uses environment variables for service-to-service communication following .NET best practices
- **ConfigMap and Secret Management**: Automatic creation of ConfigMaps for application settings and Secrets for sensitive data
- **.NET-Optimized Health Checks**: Configured for `/health` endpoints with appropriate timeouts
- **SSL/TLS Support**: Built-in support for Let's Encrypt certificates via cert-manager
- **Horizontal Pod Autoscaling**: Optional HPA configuration
- **Resource Management**: CPU and memory limits/requests
- **Infrastructure Integration**: Pre-configured for PostgreSQL, Redis, and RabbitMQ

## Quick Start

### 1. Copy the Base Chart

```bash
# Copy this chart as a template for your microservice
cp -r hello-world my-microservice-chart
cd my-microservice-chart
```

### 2. Customize for Your Microservice

Edit `values.yaml` to configure your specific microservice:

```yaml
# Example: Catalog API configuration
microservice:
  name: "catalog-api"
  environment: "production"
  port: 8080

image:
  registry: "ghcr.io/yourorg/eshop"
  repository: "catalog-api"
  tag: "1.0.0"

# Enable ingress if this service needs external access
ingress:
  enabled: true
  hosts:
    - host: catalog.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - catalog.yourdomain.com
      secretName: catalog-api-tls
```

### 3. Deploy

```bash
# Install the microservice
helm install catalog-api . --namespace eshop --create-namespace

# Or upgrade existing deployment
helm upgrade catalog-api . --namespace eshop
```

## Configuration

### Microservice Configuration

The `microservice` section defines the core settings for your service:

```yaml
microservice:
  name: "your-service-name"        # Used for naming resources
  environment: "production"        # ASPNETCORE_ENVIRONMENT
  port: 8080                      # Container port (standard for .NET)
  healthPath: "/health"           # Health check endpoint
  readyPath: "/health"            # Readiness check endpoint
```

### Image Configuration

```yaml
image:
  registry: "ghcr.io/yourorg/eshop"  # Container registry
  repository: "your-service"         # Image name
  tag: "1.0.0"                      # Image tag (defaults to Chart appVersion)
  pullPolicy: IfNotPresent
```

### Service Discovery

Configure how your microservice discovers other services:

```yaml
serviceEndpoints:
  catalogApi: "http://catalog-service"
  basketApi: "http://basket-service"
  orderingApi: "http://ordering-service"
  identityApi: "http://identity-service"
  webhooksApi: "http://webhooks-service"
```

These become environment variables in your container:
- `ServiceEndpoints__CatalogApi`
- `ServiceEndpoints__BasketApi`
- etc.

### Infrastructure Services

Configure connections to shared infrastructure:

```yaml
infrastructure:
  postgres:
    serviceName: "postgres-service"
    port: 5432
    databases:
      catalog: "catalogdb"
      identity: "identitydb"
      ordering: "orderingdb"
      webhooks: "webhooksdb"
  
  redis:
    serviceName: "redis-service"
    port: 6379
  
  eventBus:
    serviceName: "rabbitmq-service"
    port: 5672
    username: "guest"
    subscriptionClientName: ""  # Defaults to microservice name
```

### Resource Configuration

```yaml
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### Autoscaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

## Environment Variables

The chart automatically injects these environment variables into your container:

### Core Configuration
- `ASPNETCORE_ENVIRONMENT`: From `microservice.environment`
- `ASPNETCORE_URLS`: Configured to listen on the specified port
- `MicroserviceName`: From `microservice.name`

### Service Discovery
- `ServiceEndpoints__CatalogApi`: URL for Catalog API
- `ServiceEndpoints__BasketApi`: URL for Basket API
- `ServiceEndpoints__OrderingApi`: URL for Ordering API
- `ServiceEndpoints__IdentityApi`: URL for Identity API

### Infrastructure Connections
- `ConnectionStrings__Redis`: Redis connection string
- `ConnectionStrings__EventBus`: RabbitMQ connection string
- `ConnectionStrings__CatalogDB`: PostgreSQL connection (from Secret)
- `ConnectionStrings__IdentityDB`: PostgreSQL connection (from Secret)
- `EventBus__SubscriptionClientName`: For RabbitMQ subscriptions

### Application Settings
Additional settings from the ConfigMap based on `config.appSettings`.

## Secrets Management

The chart creates a Secret with connection strings and sensitive data. **Important**: The default Secret contains placeholder values. In production:

1. **External Secrets**: Use External Secrets Operator or similar
2. **Manual Override**: Create the Secret manually before deployment
3. **CI/CD Integration**: Inject real secrets during deployment

Example Secret override:
```yaml
# secrets-override.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-service-secret
type: Opaque
stringData:
  ConnectionStrings__CatalogDB: "Host=postgres-service;Database=catalogdb;Username=sa;Password=RealPassword123!"
  EventBus__Password: "RealRabbitMQPassword"
```

Apply before or after chart deployment:
```bash
kubectl apply -f secrets-override.yaml -n eshop
```

## Usage Examples

### Example 1: Catalog API

```yaml
# values-catalog-api.yaml
microservice:
  name: "catalog-api"
  environment: "production"

image:
  repository: "catalog-api"
  tag: "1.2.0"

ingress:
  enabled: false  # Internal service, no external access

resources:
  requests:
    cpu: 250m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Example 2: Web App (Frontend)

```yaml
# values-webapp.yaml
microservice:
  name: "webapp"
  environment: "production"

image:
  repository: "webapp"
  tag: "1.0.0"

ingress:
  enabled: true
  hosts:
    - host: shop.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - shop.yourdomain.com
      secretName: webapp-tls

# Webapp needs access to all backend services
serviceEndpoints:
  catalogApi: "http://catalog-service"
  basketApi: "http://basket-service"
  orderingApi: "http://ordering-service"
  identityApi: "http://identity-service"

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 300m
    memory: 256Mi
```

### Example 3: API with Autoscaling

```yaml
# values-ordering-api.yaml
microservice:
  name: "ordering-api"
  environment: "production"

image:
  repository: "ordering-api"
  tag: "1.1.0"

replicaCount: 3

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 8
  targetCPUUtilizationPercentage: 70

resources:
  requests:
    cpu: 200m
    memory: 256Mi
  limits:
    cpu: 800m
    memory: 1Gi
```

## Deployment Commands

```bash
# Deploy Catalog API
helm install catalog-api . -f values-catalog-api.yaml -n eshop

# Deploy Web App
helm install webapp . -f values-webapp.yaml -n eshop

# Deploy Ordering API with autoscaling
helm install ordering-api . -f values-ordering-api.yaml -n eshop

# Upgrade existing deployment
helm upgrade catalog-api . -f values-catalog-api.yaml -n eshop

# Check deployment status
kubectl get pods -n eshop
kubectl get services -n eshop
kubectl get ingresses -n eshop
```

## Troubleshooting

### Check Pod Logs
```bash
kubectl logs -f deployment/catalog-api -n eshop
```

### Check Configuration
```bash
# View ConfigMap
kubectl get configmap catalog-api-config -o yaml -n eshop

# View Secret (base64 encoded)
kubectl get secret catalog-api-secret -o yaml -n eshop

# View environment variables in pod
kubectl exec -it deployment/catalog-api -n eshop -- env | grep -E "(ServiceEndpoints|ConnectionStrings)"
```

### Health Check Issues
If health checks are failing:
1. Verify your .NET app exposes `/health` endpoint
2. Check if the app is listening on the correct port (8080)
3. Verify the app starts within the readiness probe timeout (10s)

### Service Discovery Issues
If services can't communicate:
1. Check service names match the `serviceEndpoints` configuration
2. Verify services are in the same namespace
3. Test connectivity: `kubectl exec -it pod-name -- nslookup service-name`

## Best Practices

1. **Use this chart as a template**: Don't modify the base chart directly
2. **Version your charts**: Keep chart versions aligned with application versions
3. **Environment-specific values**: Use separate values files for dev/staging/prod
4. **Secrets management**: Never commit real secrets to version control
5. **Resource limits**: Always set appropriate CPU/memory limits
6. **Health checks**: Ensure your .NET app implements health check endpoints
7. **Service naming**: Use consistent naming conventions across all services

## Contributing

When improving this base chart:
1. Keep it generic - specific configurations should go in values files
2. Document any new configuration options
3. Test with multiple microservices to ensure compatibility
4. Follow Helm best practices for template naming and structure