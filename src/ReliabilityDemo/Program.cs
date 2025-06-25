using ReliabilityDemo.DataStore;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.DataStore.Services;
using ReliabilityDemo.Models;
using ReliabilityDemo.Services;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// Configure from appsettings
builder.Services.Configure<DataStoreConfig>(
    builder.Configuration.GetSection("DataStore"));
builder.Services.Configure<RedisDataStoreConfig>(
    builder.Configuration.GetSection("RedisDataStore"));

// Configure data store based on provider
var dataStoreProvider = builder.Configuration.GetSection("DataStore")["Provider"] ?? "Redis";

if (dataStoreProvider.Equals("SqlServer", StringComparison.OrdinalIgnoreCase))
{
    // Add SQL Server via shared assembly
    builder.Services.AddSqlServerDataStore(builder.Configuration);
}
else
{
    // Add Redis (default)
    var redisConnectionString = builder.Configuration.GetConnectionString("Redis") ?? "localhost:6379";
    builder.Services.AddSingleton<IConnectionMultiplexer>(sp =>
    {
        return ConnectionMultiplexer.Connect(redisConnectionString);
    });
    builder.Services.AddSingleton<IDataStore, RedisDataStore>();
}

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Auto-migrate SQL Server database if configured
if (dataStoreProvider.Equals("SqlServer", StringComparison.OrdinalIgnoreCase))
{
    await app.Services.EnsureDatabaseCreatedAsync(builder.Configuration);
}

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