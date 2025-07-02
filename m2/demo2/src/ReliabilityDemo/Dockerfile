# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files
COPY ["ReliabilityDemo/ReliabilityDemo.csproj", "ReliabilityDemo/"]
COPY ["ReliabilityDemo.DataStore/ReliabilityDemo.DataStore.csproj", "ReliabilityDemo.DataStore/"]
COPY ["ReliabilityDemo.Messaging/ReliabilityDemo.Messaging.csproj", "ReliabilityDemo.Messaging/"]

# Restore dependencies
RUN dotnet restore "ReliabilityDemo/ReliabilityDemo.csproj"

# Copy source code
COPY . .

# Build application
WORKDIR "/src/ReliabilityDemo"
RUN dotnet build "ReliabilityDemo.csproj" -c Release -o /app/build

# Publish application
RUN dotnet publish "ReliabilityDemo.csproj" -c Release -o /app/publish --no-restore

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy published application
COPY --from=build /app/publish .

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Set environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/api/health || exit 1

# Entry point
ENTRYPOINT ["dotnet", "ReliabilityDemo.dll"]

# Labels for GitOps tracking
LABEL org.opencontainers.image.title="Reliability Demo Web API"
LABEL org.opencontainers.image.description="Customer management API demonstrating reliability patterns"
LABEL org.opencontainers.image.source="https://github.com/sixeyed/ps-sre3-demo2"
LABEL org.opencontainers.image.documentation="https://github.com/sixeyed/ps-sre3-demo2/blob/main/README.md"
LABEL org.opencontainers.image.vendor="SRE Training"