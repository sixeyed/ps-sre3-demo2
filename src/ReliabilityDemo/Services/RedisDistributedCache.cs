using Microsoft.Extensions.Options;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.Models;
using StackExchange.Redis;
using System.Text.Json;

namespace ReliabilityDemo.Services;

public class RedisDistributedCache : IDistributedCache
{
    private readonly IDatabase _database;
    private readonly DistributedCacheConfig _config;
    private readonly ILogger<RedisDistributedCache> _logger;
    private const string CACHE_KEY_PREFIX = "cache:customer:";
    private const string ALL_CUSTOMERS_KEY = "cache:all_customers";
    
    public RedisDistributedCache(IConnectionMultiplexer redis, IOptions<DistributedCacheConfig> config, ILogger<RedisDistributedCache> logger)
    {
        _database = redis.GetDatabase();
        _config = config.Value;
        _logger = logger;
    }
    
    public async Task<Customer?> GetCustomerAsync(int id)
    {
        if (!_config.Enabled)
            return null;
            
        try
        {
            var key = $"{CACHE_KEY_PREFIX}{id}";
            var json = await _database.StringGetAsync(key);
            
            if (!json.HasValue)
            {
                _logger.LogDebug("Cache miss for customer ID: {Id}", id);
                return null;
            }
            
            _logger.LogDebug("Cache hit for customer ID: {Id}", id);
            return JsonSerializer.Deserialize<Customer>(json!);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting customer {Id} from cache", id);
            return null;
        }
    }
    
    public async Task<Customer?> GetCustomerByEmailAsync(string email)
    {
        if (!_config.Enabled)
            return null;
            
        try
        {
            var key = $"cache:customer:email:{email}";
            var json = await _database.StringGetAsync(key);
            
            if (!json.HasValue)
            {
                _logger.LogDebug("Cache miss for customer email: {Email}", email);
                return null;
            }
            
            _logger.LogDebug("Cache hit for customer email: {Email}", email);
            return JsonSerializer.Deserialize<Customer>(json!);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting customer by email {Email} from cache", email);
            return null;
        }
    }
    
    public async Task<IEnumerable<Customer>?> GetAllCustomersAsync()
    {
        if (!_config.Enabled)
            return null;
            
        try
        {
            var json = await _database.StringGetAsync(ALL_CUSTOMERS_KEY);
            
            if (!json.HasValue)
            {
                _logger.LogDebug("Cache miss for all customers");
                return null;
            }
            
            _logger.LogDebug("Cache hit for all customers");
            return JsonSerializer.Deserialize<IEnumerable<Customer>>(json!);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting all customers from cache");
            return null;
        }
    }
    
    public async Task SetCustomerAsync(Customer customer)
    {
        if (!_config.Enabled)
            return;
            
        try
        {
            var idKey = $"{CACHE_KEY_PREFIX}{customer.Id}";
            var emailKey = $"cache:customer:email:{customer.Email}";
            var json = JsonSerializer.Serialize(customer);
            var expiry = TimeSpan.FromSeconds(_config.ExpirationSeconds);
            
            // Cache by both ID and email
            await _database.StringSetAsync(idKey, json, expiry);
            await _database.StringSetAsync(emailKey, json, expiry);
            _logger.LogDebug("Cached customer ID: {Id} and email: {Email} with TTL: {TTL}s", customer.Id, customer.Email, _config.ExpirationSeconds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error caching customer {Id}", customer.Id);
        }
    }
    
    public async Task SetAllCustomersAsync(IEnumerable<Customer> customers)
    {
        if (!_config.Enabled)
            return;
            
        try
        {
            var json = JsonSerializer.Serialize(customers);
            var expiry = TimeSpan.FromSeconds(_config.ExpirationSeconds);
            
            await _database.StringSetAsync(ALL_CUSTOMERS_KEY, json, expiry);
            _logger.LogDebug("Cached all customers ({Count} items) with TTL: {TTL}s", customers.Count(), _config.ExpirationSeconds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error caching all customers");
        }
    }
    
    public async Task InvalidateCustomerAsync(int id)
    {
        if (!_config.Enabled)
            return;
            
        try
        {
            var key = $"{CACHE_KEY_PREFIX}{id}";
            await _database.KeyDeleteAsync(key);
            _logger.LogDebug("Invalidated cache for customer ID: {Id}", id);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error invalidating cache for customer {Id}", id);
        }
    }
    
    public async Task InvalidateCustomerByEmailAsync(string email)
    {
        if (!_config.Enabled)
            return;
            
        try
        {
            var key = $"cache:customer:email:{email}";
            await _database.KeyDeleteAsync(key);
            _logger.LogDebug("Invalidated cache for customer email: {Email}", email);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error invalidating cache for customer email {Email}", email);
        }
    }
    
    public async Task InvalidateAllCustomersAsync()
    {
        if (!_config.Enabled)
            return;
            
        try
        {
            await _database.KeyDeleteAsync(ALL_CUSTOMERS_KEY);
            _logger.LogDebug("Invalidated cache for all customers");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error invalidating all customers cache");
        }
    }
}