using ReliabilityDemo.DataStore;
using ReliabilityDemo.DataStore.Services;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.Worker;
using ReliabilityDemo.Messaging;
using StackExchange.Redis;

var builder = Host.CreateApplicationBuilder(args);

// Load multiple configuration files
builder.Configuration
    .AddJsonFile("config/logging.json", optional: true, reloadOnChange: true)
    .AddJsonFile("config/shared.json", optional: true, reloadOnChange: true)
    .AddJsonFile("config/worker.json", optional: true, reloadOnChange: true);

// Configure messaging settings
builder.Services.Configure<MessagingConfig>(
    builder.Configuration.GetSection("Messaging"));

// Configure distributed cache settings
builder.Services.Configure<DistributedCacheConfig>(
    builder.Configuration.GetSection("DistributedCache"));

// Configure Redis connection for messaging
var redisConnectionString = builder.Configuration.GetConnectionString("Redis") ?? "localhost:6379";
builder.Services.AddSingleton<IConnectionMultiplexer>(sp =>
{
    return ConnectionMultiplexer.Connect(redisConnectionString);
});

// Configure data store - only SQL Server now
builder.Services.AddSqlServerDataStore(builder.Configuration);

// Add distributed cache service (uses Redis for caching)
builder.Services.AddSingleton<IDistributedCache, RedisDistributedCache>();

// Add the worker service
builder.Services.AddHostedService<CustomerMessageWorker>();

var host = builder.Build();

// Auto-migrate SQL Server database
await host.Services.EnsureDatabaseCreatedAsync(builder.Configuration);

await host.RunAsync();