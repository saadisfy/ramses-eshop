# Catalog API v2 - Using baseChart Dependency

This is the second version of the Catalog API Helm chart that leverages the `baseChart` as a dependency instead of containing all templates inline.

## Architecture

- **baseChart**: Provides all the common Kubernetes templates (Deployment, Service, Ingress, PostgreSQL, etc.)
- **catalog-api-v2**: Configures the baseChart specifically for the Catalog API microservice

## Dependencies

1. **baseChart** (v0.1.0): Base application chart (included locally in `charts/baseChart/`)
2. **rabbitmq** (v14.6.6): Bitnami RabbitMQ chart for event bus

## Key Features

- ✅ PostgreSQL with pgvector extension for vector search capabilities
- ✅ RabbitMQ for event-driven architecture
- ✅ Ingress with SSL/TLS termination
- ✅ Configurable environment (Development/Production)
- ✅ Health checks and resource management
- ✅ Service account creation

## Usage

1. **Install dependencies** (baseChart is included locally):
   ```bash
   helm dependency update helm/charts/catalog-api-v2
   ```

2. **Deploy the chart**:
   ```bash
   helm install catalog-api-v2 helm/charts/catalog-api-v2
   ```

3. **Override values** as needed:
   ```bash
   helm install catalog-api-v2 helm/charts/catalog-api-v2 \
     --set app.application.environment=Production \
     --set app.image.tag=1.1.0
   ```

## Configuration

All configuration is done through the `app` key which corresponds to the baseChart values. See `values.yaml` for the complete configuration structure.

### Key Configuration Sections

- `app.application.*`: Application-specific settings (name, port, environment)
- `app.image.*`: Container image configuration
- `app.postgresql.*`: Database configuration with pgvector support
- `app.rabbitmq.*`: Event bus configuration
- `app.ingress.*`: Load balancer and SSL configuration

## Differences from catalog-api v1

- **No templates directory**: Templates come from baseChart dependency
- **Structured configuration**: All config under `app` key
- **Dependency-based**: Cleaner separation of concerns
- **Reusable**: baseChart can be used for other microservices