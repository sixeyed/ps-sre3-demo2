using Microsoft.AspNetCore.Mvc;
using ReliabilityDemo.DataStore.Services;
using ReliabilityDemo.Services;

namespace ReliabilityDemo.Controllers;

[ApiController]
[Route("api/admin")]
public class AdminController : ControllerBase
{
    // Event IDs for structured logging
    private static class EventIds
    {
        public static readonly EventId AdminResetRequest = new(5001, "AdminResetRequest");
        public static readonly EventId AdminDbCleared = new(5002, "AdminDbCleared");
        public static readonly EventId AdminCacheCleared = new(5003, "AdminCacheCleared");
    }
    
    private readonly IDataStore _dataStore;
    private readonly IDistributedCache _cache;
    private readonly ILogger<AdminController> _logger;

    public AdminController(IDataStore dataStore, IDistributedCache cache, ILogger<AdminController> logger)
    {
        _dataStore = dataStore;
        _cache = cache;
        _logger = logger;
    }

    [HttpPost("reset")]
    public async Task<IActionResult> ResetDatabase()
    {
        _logger.LogInformation(EventIds.AdminResetRequest, "Admin reset requested | Action: DatabaseAndCacheReset");
        
        try
        {
            // Clear the database
            await _dataStore.ClearAllCustomersAsync();
            _logger.LogInformation(EventIds.AdminDbCleared, "Database cleared successfully | Action: DatabaseClear");

            // Clear all cache entries
            await _cache.InvalidateAllAsync();
            _logger.LogInformation(EventIds.AdminCacheCleared, "Cache cleared successfully | Action: CacheClear");

            return Ok(new { 
                message = "Database and cache reset completed successfully",
                timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred during admin reset");
            return StatusCode(500, new { 
                error = "Failed to reset database and cache",
                details = ex.Message
            });
        }
    }

    [HttpGet("status")]
    public async Task<IActionResult> GetStatus()
    {
        try
        {
            var customerCount = await _dataStore.GetCustomerCountAsync();
            var cacheStatus = await _cache.GetCacheStatusAsync();
            
            return Ok(new {
                database = new {
                    customerCount = customerCount,
                    provider = _dataStore.GetType().Name
                },
                cache = cacheStatus,
                timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting admin status");
            return StatusCode(500, new { 
                error = "Failed to get status",
                details = ex.Message
            });
        }
    }
}