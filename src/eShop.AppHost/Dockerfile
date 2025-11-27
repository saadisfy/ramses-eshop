# Multi-stage build for eShop AppHost
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Set working directory
WORKDIR /src

# Copy the project file and restore dependencies
COPY ["eShop.AppHost/eShop.AppHost.csproj", "eShop.AppHost/"]
COPY ["Basket.API/Basket.API.csproj", "Basket.API/"]
COPY ["Catalog.API/Catalog.API.csproj", "Catalog.API/"]
COPY ["Identity.API/Identity.API.csproj", "Identity.API/"]
COPY ["Ordering.API/Ordering.API.csproj", "Ordering.API/"]
COPY ["OrderProcessor/OrderProcessor.csproj", "OrderProcessor/"]
COPY ["PaymentProcessor/PaymentProcessor.csproj", "PaymentProcessor/"]
COPY ["Webhooks.API/Webhooks.API.csproj", "Webhooks.API/"]
COPY ["WebApp/WebApp.csproj", "WebApp/"]
COPY ["WebhookClient/WebhookClient.csproj", "WebhookClient/"]
COPY ["Mobile.Bff.Shopping/Mobile.Bff.Shopping.csproj", "Mobile.Bff.Shopping/"]
COPY ["eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "eShop.ServiceDefaults/"]
COPY ["EventBus/EventBus.csproj", "EventBus/"]
COPY ["EventBusRabbitMQ/EventBusRabbitMQ.csproj", "EventBusRabbitMQ/"]
COPY ["IntegrationEventLogEF/IntegrationEventLogEF.csproj", "IntegrationEventLogEF/"]
COPY ["Ordering.Domain/Ordering.Domain.csproj", "Ordering.Domain/"]
COPY ["Ordering.Infrastructure/Ordering.Infrastructure.csproj", "Ordering.Infrastructure/"]
COPY ["WebAppComponents/WebAppComponents.csproj", "WebAppComponents/"]

# Copy Directory.Build files
COPY ["Directory.Build.props", "Directory.Build.targets", "./"]

# Restore dependencies
RUN dotnet restore "eShop.AppHost/eShop.AppHost.csproj"

# Copy the rest of the source code
COPY . .

# Build arguments
ARG BUILD_CONFIGURATION=Release
ARG BUILD_PLATFORM=linux-x64

# Build the application
RUN dotnet build "eShop.AppHost/eShop.AppHost.csproj" \
    --configuration $BUILD_CONFIGURATION \
    --no-restore \
    --runtime $BUILD_PLATFORM

# Publish the application
RUN dotnet publish "eShop.AppHost/eShop.AppHost.csproj" \
    --configuration $BUILD_CONFIGURATION \
    --no-build \
    --output /app/publish \
    --runtime $BUILD_PLATFORM \
    --self-contained false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

# Set working directory
WORKDIR /app

# Install necessary packages for Aspire
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the published application
COPY --from=build /app/publish .

# Expose ports
EXPOSE 8080
EXPOSE 8081

# Set environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the application
ENTRYPOINT ["dotnet", "eShop.AppHost.dll"] 