# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-env
WORKDIR /app

# Copy shared projects
COPY ReliabilityDemo.DataStore/ ./ReliabilityDemo.DataStore/
COPY ReliabilityDemo.Messaging/ ./ReliabilityDemo.Messaging/

# Copy worker project files
COPY ReliabilityDemo.Worker/*.csproj ./ReliabilityDemo.Worker/
RUN dotnet restore ReliabilityDemo.Worker/ReliabilityDemo.Worker.csproj

# Copy worker source code
COPY ReliabilityDemo.Worker/ ./ReliabilityDemo.Worker/

# Build and publish
RUN dotnet publish ReliabilityDemo.Worker/ReliabilityDemo.Worker.csproj -c Release -o out

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app

# Copy published output
COPY --from=build-env /app/out .

# Set environment variable to indicate this is a containerized environment
ENV DOTNET_RUNNING_IN_CONTAINER=true

# Run the worker
ENTRYPOINT ["dotnet", "ReliabilityDemo.Worker.dll"]