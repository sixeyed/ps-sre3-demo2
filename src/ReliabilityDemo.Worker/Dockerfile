# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["ReliabilityDemo.Worker/ReliabilityDemo.Worker.csproj", "ReliabilityDemo.Worker/"]
COPY ["ReliabilityDemo.DataStore/ReliabilityDemo.DataStore.csproj", "ReliabilityDemo.DataStore/"]
COPY ["ReliabilityDemo.Messaging/ReliabilityDemo.Messaging.csproj", "ReliabilityDemo.Messaging/"]

# Restore dependencies
RUN dotnet restore "ReliabilityDemo.Worker/ReliabilityDemo.Worker.csproj"

# Copy source code
COPY . .

# Build application
WORKDIR "/src/ReliabilityDemo.Worker"
RUN dotnet build "ReliabilityDemo.Worker.csproj" -c Release -o /app/build

# Publish application
RUN dotnet publish "ReliabilityDemo.Worker.csproj" -c Release -o /app/publish --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/runtime:8.0 AS runtime
WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy published application
COPY --from=build /app/publish .

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set environment variables
ENV ASPNETCORE_ENVIRONMENT=Production

# Entry point
ENTRYPOINT ["dotnet", "ReliabilityDemo.Worker.dll"]