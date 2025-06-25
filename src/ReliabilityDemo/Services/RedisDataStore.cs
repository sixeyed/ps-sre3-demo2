using Microsoft.Extensions.Options;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.DataStore.Services;
using StackExchange.Redis;
using System.Text.Json;

namespace ReliabilityDemo.Services;

public class RedisDataStore : IDataStore
{
    private readonly IDatabase _database;
    private readonly RedisDataStoreConfig _config;
    private static int _concurrentClients = 0;
    private static readonly object _lock = new object();
    private const string CUSTOMER_KEY_PREFIX = "customer:";
    private const string CUSTOMER_ID_COUNTER = "customer:id:counter";
    
    public RedisDataStore(IConnectionMultiplexer redis, IOptions<RedisDataStoreConfig> config)
    {
        _database = redis.GetDatabase();
        _config = config.Value;
    }
    
    private void CheckConcurrentClients()
    {
        lock (_lock)
        {
            if (_concurrentClients >= _config.MaxConcurrentClients)
            {
                throw new InvalidOperationException($"Too many concurrent clients. Maximum allowed: {_config.MaxConcurrentClients}, current: {_concurrentClients}");
            }
            _concurrentClients++;
        }
    }
    
    private void ReleaseConcurrentClient()
    {
        lock (_lock)
        {
            _concurrentClients--;
        }
    }
    
    public async Task<Customer?> GetCustomerAsync(int id)
    {
        CheckConcurrentClients();
        try
        {
            await Task.Delay(50); // Simulate database latency
            var json = await _database.StringGetAsync($"{CUSTOMER_KEY_PREFIX}{id}");
            return json.HasValue ? JsonSerializer.Deserialize<Customer>(json!) : null;
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<Customer> CreateCustomerAsync(Customer customer)
    {
        CheckConcurrentClients();
        try
        {
            await Task.Delay(100); // Simulate database write latency
            
            // Generate new ID
            var newId = await _database.StringIncrementAsync(CUSTOMER_ID_COUNTER);
            customer.Id = (int)newId;
            customer.CreatedAt = DateTime.UtcNow;
            customer.UpdatedAt = null;
            
            var json = JsonSerializer.Serialize(customer);
            await _database.StringSetAsync($"{CUSTOMER_KEY_PREFIX}{customer.Id}", json);
            
            return customer;
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<Customer> UpdateCustomerAsync(Customer customer)
    {
        CheckConcurrentClients();
        try
        {
            await Task.Delay(100); // Simulate database write latency
            
            customer.UpdatedAt = DateTime.UtcNow;
            var json = JsonSerializer.Serialize(customer);
            await _database.StringSetAsync($"{CUSTOMER_KEY_PREFIX}{customer.Id}", json);
            
            return customer;
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<bool> DeleteCustomerAsync(int id)
    {
        CheckConcurrentClients();
        try
        {
            await Task.Delay(50); // Simulate database latency
            return await _database.KeyDeleteAsync($"{CUSTOMER_KEY_PREFIX}{id}");
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<IEnumerable<Customer>> GetAllCustomersAsync()
    {
        CheckConcurrentClients();
        try
        {
            await Task.Delay(200); // Simulate full table scan
            var server = _database.Multiplexer.GetServer(_database.Multiplexer.GetEndPoints().First());
            var keys = server.Keys(pattern: $"{CUSTOMER_KEY_PREFIX}*");
            var customers = new List<Customer>();
            
            foreach (var key in keys)
            {
                var json = await _database.StringGetAsync(key);
                if (json.HasValue)
                {
                    var customer = JsonSerializer.Deserialize<Customer>(json!);
                    if (customer != null)
                        customers.Add(customer);
                }
            }
            
            return customers.OrderBy(c => c.Id);
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
}