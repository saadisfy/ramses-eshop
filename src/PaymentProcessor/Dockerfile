# Multi-stage build for PaymentProcessor
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Set working directory
WORKDIR /src

# Copy the project file and restore dependencies
COPY ["PaymentProcessor/PaymentProcessor.csproj", "PaymentProcessor/"]
COPY ["eShop.ServiceDefaults/eShop.ServiceDefaults.csproj", "eShop.ServiceDefaults/"]
COPY ["EventBus/EventBus.csproj", "EventBus/"]
COPY ["EventBusRabbitMQ/EventBusRabbitMQ.csproj", "EventBusRabbitMQ/"]

# Copy Directory.Build files
COPY ["Directory.Build.props", "Directory.Build.targets", "./"]

# Restore dependencies
RUN dotnet restore "PaymentProcessor/PaymentProcessor.csproj"

# Copy the rest of the source code
COPY . .

# Build arguments
ARG BUILD_CONFIGURATION=Release
ARG BUILD_PLATFORM=linux-x64

# Build the application
RUN dotnet build "PaymentProcessor/PaymentProcessor.csproj" \
    --configuration $BUILD_CONFIGURATION \
    --no-restore \
    --runtime $BUILD_PLATFORM

# Publish the application
RUN dotnet publish "PaymentProcessor/PaymentProcessor.csproj" \
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

# Set environment variables
ENV ASPNETCORE_ENVIRONMENT=Production

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD dotnet --version || exit 1

# Run the application
ENTRYPOINT ["dotnet", "PaymentProcessor.dll"] 