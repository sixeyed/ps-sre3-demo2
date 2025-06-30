using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using ReliabilityDemo.DataStore.Data;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.DataStore.Services;

namespace ReliabilityDemo.DataStore;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddSqlServerDataStore(this IServiceCollection services, IConfiguration configuration)
    {
        // Configure options
        services.Configure<FailureConfig>(configuration.GetSection("FailureConfig"));
        services.Configure<SqlServerDataStoreConfig>(configuration.GetSection("SqlServerDataStore"));
        
        // Add SQL Server DbContext
        var connectionString = configuration.GetConnectionString("SqlServer") ?? 
                              "Server=(localdb)\\mssqllocaldb;Database=ReliabilityDemo;Trusted_Connection=true;";
        
        services.AddDbContext<ReliabilityDemoContext>(options =>
            options.UseSqlServer(connectionString));
        
        // Register data store
        services.AddScoped<IDataStore, SqlServerDataStore>();
        
        return services;
    }
    
    public static async Task EnsureDatabaseCreatedAsync(this IServiceProvider serviceProvider, IConfiguration configuration)
    {
        var config = configuration.GetSection("SqlServerDataStore").Get<SqlServerDataStoreConfig>() ?? new SqlServerDataStoreConfig();
        
        if (config.AutoMigrate)
        {
            using var scope = serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ReliabilityDemoContext>();
            await context.Database.EnsureCreatedAsync();
        }
    }
}