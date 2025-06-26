using ReliabilityDemo.DataStore;
using ReliabilityDemo.DataStore.Services;
using ReliabilityDemo.Models;
using ReliabilityDemo.Services;
using ReliabilityDemo.Messaging;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// Load multiple configuration files
builder.Configuration
    .AddJsonFile("config/logging.json", optional: true, reloadOnChange: true)
    .AddJsonFile("config/shared.json", optional: true, reloadOnChange: true)
    .AddJsonFile("config/web.json", optional: true, reloadOnChange: true);

// Configure from appsettings
builder.Services.Configure<DistributedCacheConfig>(
    builder.Configuration.GetSection("DistributedCache"));
builder.Services.Configure<MessagingConfig>(
    builder.Configuration.GetSection("Messaging"));
builder.Services.Configure<CustomerOperationConfig>(
    builder.Configuration.GetSection("CustomerOperation"));

// Configure data store - only SQL Server now
builder.Services.AddSqlServerDataStore(builder.Configuration);

// Add distributed cache service (always uses Redis for caching)
var cacheRedisConnectionString = builder.Configuration.GetConnectionString("Redis") ?? "localhost:6379";
if (!builder.Services.Any(s => s.ServiceType == typeof(IConnectionMultiplexer)))
{
    builder.Services.AddSingleton<IConnectionMultiplexer>(sp =>
    {
        return ConnectionMultiplexer.Connect(cacheRedisConnectionString);
    });
}
builder.Services.AddSingleton<IDistributedCache, RedisDistributedCache>();

// Add messaging services (always uses Redis for pub/sub)
builder.Services.AddSingleton<IMessagePublisher, RedisMessagePublisher>();

// Configure customer operation service based on pattern
var customerOperationPattern = builder.Configuration.GetSection("CustomerOperation")["Pattern"] ?? "Direct";

if (customerOperationPattern.Equals("Async", StringComparison.OrdinalIgnoreCase))
{
    builder.Services.AddScoped<ICustomerOperationService, AsyncCustomerService>();
}
else
{
    builder.Services.AddScoped<ICustomerOperationService, DirectCustomerService>();
}

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Auto-migrate SQL Server database
await app.Services.EnsureDatabaseCreatedAsync(builder.Configuration);

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseRouting();
app.MapControllers();

// Serve static files for the web app
app.UseStaticFiles();
app.MapFallbackToFile("index.html");

app.Run();