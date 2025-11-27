# Multi-stage build for Ordering.API
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Set working directory
WORKDIR /src

# Copy the project file and restore dependencies
COPY ["Ordering.API/Ordering.API.csproj", "Ordering.API/"]
COPY ["Ordering.Domain/Ordering.Domain.csproj", "Ordering.Domain/"]
COPY ["Ordering.Infrastructure/Ordering.Infrastructure.csproj", "Ordering.Infrastructure/"]
COPY ["eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "eShop.ServiceDefaults/"]
COPY ["EventBus/EventBus.csproj", "EventBus/"]
COPY ["EventBusRabbitMQ/EventBusRabbitMQ.csproj", "EventBusRabbitMQ/"]
COPY ["IntegrationEventLogEF/IntegrationEventLogEF.csproj", "IntegrationEventLogEF/"]

# Copy Directory.Build files
COPY ["Directory.Build.props", "Directory.Build.targets", "./"]

# Restore dependencies
RUN dotnet restore "Ordering.API/Ordering.API.csproj"

# Copy the rest of the source code
COPY . .

# Build arguments
ARG BUILD_CONFIGURATION=Release
ARG BUILD_PLATFORM=linux-x64

# Build the application
RUN dotnet build "Ordering.API/Ordering.API.csproj" \
    --configuration $BUILD_CONFIGURATION \
    --no-restore \
    --runtime $BUILD_PLATFORM

# Publish the application
RUN dotnet publish "Ordering.API/Ordering.API.csproj" \
    --configuration $BUILD_CONFIGURATION \
    --no-build \
    --output /app/publish \
    --runtime $BUILD_PLATFORM \
    --self-contained false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

# Set working directory
WORKDIR /app

# Install necessary packages
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
ENTRYPOINT ["dotnet", "Ordering.API.dll"] 