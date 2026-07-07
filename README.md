# eShop Reference Application Mirror

Mirror of the .NET eShop reference application used in the RAMSES thesis context.

The repository keeps the original eShop application code and history while making its role in the RAMSES repository set explicit. eShop is a larger microservice reference application that can be used for comparison, deployment experiments, and future adaptation scenarios alongside the SEFA managed system.

## Original project context

eShop is a .NET Aspire-based e-commerce sample application. The original upstream project is maintained by Microsoft at [dotnet/eShop](https://github.com/dotnet/eShop).

This mirror is kept under the RAMSES thesis GitHub namespace so it can be referenced from the thesis implementation and deployment repositories without relying on the original GitLab subgroup layout.

## Getting started

This version is based on .NET 9.

Prerequisites:

- .NET 9 SDK
- Docker Desktop or a compatible Docker engine

Run the application locally:

```bash
dotnet run --project src/eShop.AppHost/eShop.AppHost.csproj
```

The Aspire dashboard URL is printed in the command output.

## Repository notes

- `src/`: eShop application services and AppHost.
- `tests/` and `e2e/`: test material from the reference application.
- `img/`: architecture and application screenshots.
- `ci.yml`: CI definition mirrored with the repository.

## Related repositories

- [RAMSES](https://github.com/saadisfy/ramses): main thesis implementation context.
- [SEFA managed system](https://github.com/saadisfy/ramses-sefa): primary managed system used in the thesis setup.
- [ClusterServices](https://github.com/saadisfy/ramses-clusterservices): Noctua server and Kubernetes cluster services setup.
- [basechart](https://github.com/saadisfy/ramses-basechart): reusable Helm base chart.
- [Master thesis](https://github.com/saadisfy/SDQ_MasterThesis): written thesis material.
