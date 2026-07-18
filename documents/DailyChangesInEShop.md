# Daily Changes Log

## Date: July 30, 2025

### Summary
Established Helm chart for Catalog API microservice deployment. Required custom PostgreSQL deployment with pgvector extension as Bitnami chart doesn't support vector extensions.

---

## 1. Helm Chart Setup

### Problem
- Needed Helm chart for Catalog API microservice
- Required PostgreSQL with pgvector extension for AI/ML features
- Bitnami PostgreSQL chart doesn't include vector extension

### Solution
- **Created base chart**: Generic Helm chart template for microservices
- **Custom PostgreSQL**: Direct deployment using `pgvector/pgvector:0.8.0-pg17-bookworm` image
- **Vector extension**: Added `CREATE EXTENSION IF NOT EXISTS vector;` initialization script
  - SQL command that runs when PostgreSQL starts for the first time
  - Mounted into the PostgreSQL container as initialization script
  - Ensures vector extension is available before Catalog API tries to use it
  - Prevents "extension 'vector' is not available" errors

### Key Configuration
```yaml
# Custom PostgreSQL with pgvector
image: pgvector/pgvector:0.8.0-pg17-bookworm
env:
- name: PGDATA
  value: /var/lib/postgresql/data/pgdata
```

### Testing
- **PostgreSQL**: Successfully deployed with vector extension
- **Catalog API**: Application connects and starts properly
- **API endpoints**: Verified working with port-forward testing

---

