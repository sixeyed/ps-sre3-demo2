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


# Entry point
ENTRYPOINT ["dotnet", "ReliabilityDemo.dll"]
