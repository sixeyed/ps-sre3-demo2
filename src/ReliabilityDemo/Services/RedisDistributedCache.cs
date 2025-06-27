using Microsoft.Extensions.Options;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.Models;
using StackExchange.Redis;
using System.Text.Json;

namespace ReliabilityDemo.Services;

public class RedisDistributedCache : IDistributedCache
{
    // Event IDs for structured logging
    private static class EventIds
    {
        public static readonly EventId CacheHit = new(3001, "CacheHit");
        public static readonly EventId CacheMiss = new(3002, "CacheMiss");
        public static readonly EventId CacheHitEmail = new(3003, "CacheHitEmail");
        public static readonly EventId CacheMissEmail = new(3004, "CacheMissEmail");
        public static readonly EventId CacheHitAll = new(3005, "CacheHitAll");
        public static readonly EventId CacheMissAll = new(3006, "CacheMissAll");
        public static readonly EventId CacheSet = new(3007, "CacheSet");
        public static readonly EventId CacheSetAll = new(3008, "CacheSetAll");
        public static readonly EventId CacheInvalidate = new(3009, "CacheInvalidate");
        public static readonly EventId CacheInvalidateEmail = new(3010, "CacheInvalidateEmail");
        public static readonly EventId CacheInvalidateAll = new(3011, "CacheInvalidateAll");
        public static readonly EventId CacheClearEmpty = new(3012, "CacheClearEmpty");
    }
    
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
                _logger.LogInformation(EventIds.CacheMiss, "Cache miss for customer | CustomerId: {Id} | CacheType: Customer", id);
                return null;
            }
            
            _logger.LogInformation(EventIds.CacheHit, "Cache hit for customer | CustomerId: {Id} | CacheType: Customer", id);
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
                _logger.LogInformation(EventIds.CacheMissEmail, "Cache miss for customer by email | Email: {Email} | CacheType: Customer", email);
                return null;
            }
            
            _logger.LogInformation(EventIds.CacheHitEmail, "Cache hit for customer by email | Email: {Email} | CacheType: Customer", email);
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
                _logger.LogInformation(EventIds.CacheMissAll, "Cache miss for all customers | CacheType: AllCustomers");
                return null;
            }
            
            _logger.LogInformation(EventIds.CacheHitAll, "Cache hit for all customers | CacheType: AllCustomers");
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
            _logger.LogInformation(EventIds.CacheSet, "Customer cached | CustomerId: {Id} | Email: {Email} | TTL: {TTL}s | CacheType: Customer", customer.Id, customer.Email, _config.ExpirationSeconds);
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
            _logger.LogInformation(EventIds.CacheSetAll, "All customers cached | Count: {Count} | TTL: {TTL}s | CacheType: AllCustomers", customers.Count(), _config.ExpirationSeconds);
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
            _logger.LogInformation(EventIds.CacheInvalidate, "Cache invalidated for customer | CustomerId: {Id} | CacheType: Customer", id);
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
            _logger.LogInformation(EventIds.CacheInvalidateEmail, "Cache invalidated for customer by email | Email: {Email} | CacheType: Customer", email);
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
            _logger.LogInformation(EventIds.CacheInvalidateAll, "Cache invalidated for all customers | CacheType: AllCustomers");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error invalidating all customers cache");
        }
    }

    public async Task InvalidateAllAsync()
    {
        if (!_config.Enabled)
            return;
            
        try
        {
            var server = _database.Multiplexer.GetServer(_database.Multiplexer.GetEndPoints().First());
            var keys = server.Keys(pattern: "cache:*");
            
            if (keys.Any())
            {
                await _database.KeyDeleteAsync(keys.ToArray());
                _logger.LogInformation("Invalidated all cache entries ({Count} keys)", keys.Count());
            }
            else
            {
                _logger.LogInformation(EventIds.CacheClearEmpty, "No cache entries to invalidate | CacheType: All");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error invalidating all cache entries");
        }
    }

    public async Task<object> GetCacheStatusAsync()
    {
        try
        {
            var server = _database.Multiplexer.GetServer(_database.Multiplexer.GetEndPoints().First());
            var keys = server.Keys(pattern: "cache:*");
            var keyCount = keys.Count();
            
            return new
            {
                enabled = _config.Enabled,
                keyCount = keyCount,
                expirationSeconds = _config.ExpirationSeconds,
                connection = _database.Multiplexer.IsConnected ? "Connected" : "Disconnected"
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting cache status");
            return new
            {
                enabled = _config.Enabled,
                error = ex.Message
            };
        }
    }
}