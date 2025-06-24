using Microsoft.EntityFrameworkCore;
using ReliabilityDemo.Data;
using ReliabilityDemo.Models;
using ReliabilityDemo.Services;
using StackExchange.Redis;

var builder = WebApplication.CreateBuilder(args);

// Configure from appsettings
builder.Services.Configure<FailureConfig>(
    builder.Configuration.GetSection("FailureConfig"));
builder.Services.Configure<DataStoreConfig>(
    builder.Configuration.GetSection("DataStore"));
builder.Services.Configure<RedisDataStoreConfig>(
    builder.Configuration.GetSection("RedisDataStore"));
builder.Services.Configure<SqlServerDataStoreConfig>(
    builder.Configuration.GetSection("SqlServerDataStore"));

// Configure data store based on provider
var dataStoreProvider = builder.Configuration.GetSection("DataStore")["Provider"] ?? "Redis";

if (dataStoreProvider.Equals("SqlServer", StringComparison.OrdinalIgnoreCase))
{
    // Add SQL Server
    var sqlConnectionString = builder.Configuration.GetConnectionString("SqlServer") ?? "Server=(localdb)\\mssqllocaldb;Database=ReliabilityDemo;Trusted_Connection=true;";
    builder.Services.AddDbContext<ReliabilityDemoContext>(options =>
        options.UseSqlServer(sqlConnectionString));
    builder.Services.AddScoped<IDataStore, SqlServerDataStore>();
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
builder.Services.AddSingleton<FailureSimulator>();

var app = builder.Build();

// Auto-migrate SQL Server database if configured
if (dataStoreProvider.Equals("SqlServer", StringComparison.OrdinalIgnoreCase))
{
    var sqlServerConfig = builder.Configuration.GetSection("SqlServerDataStore").Get<SqlServerDataStoreConfig>() ?? new SqlServerDataStoreConfig();
    if (sqlServerConfig.AutoMigrate)
    {
        using var scope = app.Services.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ReliabilityDemoContext>();
        context.Database.EnsureCreated();
    }
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