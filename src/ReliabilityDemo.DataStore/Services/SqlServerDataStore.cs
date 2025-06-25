using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using ReliabilityDemo.DataStore.Data;
using ReliabilityDemo.DataStore.Models;

namespace ReliabilityDemo.DataStore.Services;

public class SqlServerDataStore : IDataStore
{
    private readonly ReliabilityDemoContext _context;
    private readonly SqlServerDataStoreConfig _config;
    private readonly FailureConfig _failureConfig;
    private readonly Random _random = new();
    private readonly ILogger<SqlServerDataStore> _logger;
    private static int _concurrentClients = 0;
    private static readonly object _lock = new object();
    
    public SqlServerDataStore(ReliabilityDemoContext context, IOptions<SqlServerDataStoreConfig> config, IOptions<FailureConfig> failureConfig, ILogger<SqlServerDataStore> logger)
    {
        _context = context;
        _config = config.Value;
        _failureConfig = failureConfig.Value;
        _logger = logger;
    }
    
    private async Task SimulateFailure(string operation)
    {
        if (!_failureConfig.Enabled)
            return;

        // Simulate connection failures
        if (ShouldFail(_failureConfig.ConnectionFailureRate))
        {
            _logger.LogWarning("Simulating connection failure for operation: {Operation}", operation);
            throw new InvalidOperationException("Connection failed - service unavailable");
        }

        // Simulate read timeouts
        if (operation == "read" && ShouldFail(_failureConfig.ReadTimeoutRate))
        {
            _logger.LogWarning("Simulating read timeout for operation: {Operation}, delay: {DelayMs}ms", operation, _failureConfig.ReadTimeoutMs);
            await Task.Delay(_failureConfig.ReadTimeoutMs);
            throw new TimeoutException("Read operation timed out");
        }

        // Simulate write timeouts
        if (operation == "write" && ShouldFail(_failureConfig.WriteTimeoutRate))
        {
            _logger.LogWarning("Simulating write timeout for operation: {Operation}, delay: {DelayMs}ms", operation, _failureConfig.WriteTimeoutMs);
            await Task.Delay(_failureConfig.WriteTimeoutMs);
            throw new TimeoutException("Write operation timed out");
        }

        // Simulate slow responses
        if (ShouldFail(_failureConfig.SlowResponseRate))
        {
            _logger.LogWarning("Simulating slow response for operation: {Operation}, delay: {DelayMs}ms", operation, _failureConfig.SlowResponseDelayMs);
            await Task.Delay(_failureConfig.SlowResponseDelayMs);
        }
    }

    private bool ShouldFail(double rate)
    {
        var randomValue = _random.NextDouble();
        var shouldFail = randomValue < rate;
        _logger.LogTrace("ShouldFail check: rate={Rate}, random={Random}, result={Result}", rate, randomValue, shouldFail);
        return shouldFail;
    }
    
    private void CheckConcurrentClients()
    {
        lock (_lock)
        {
            _logger.LogTrace("CheckConcurrentClients: current={Current}, max={Max}", _concurrentClients, _config.MaxConcurrentClients);
            if (_concurrentClients >= _config.MaxConcurrentClients)
            {
                _logger.LogError("Too many concurrent clients, throttling: current={Current}, max={Max}", _concurrentClients, _config.MaxConcurrentClients);
                throw new InvalidOperationException($"Too many concurrent clients. Maximum allowed: {_config.MaxConcurrentClients}, current: {_concurrentClients}");
            }
            _concurrentClients++;
            _logger.LogTrace("Incremented concurrent clients: new count={Count}", _concurrentClients);
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
        await SimulateFailure("read");
        CheckConcurrentClients();
        try
        {
            await Task.Delay(50); // Simulate database latency
            return await _context.Customers.FindAsync(id);
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<Customer> CreateCustomerAsync(Customer customer)
    {
        await SimulateFailure("write");
        CheckConcurrentClients();
        try
        {
            await Task.Delay(100); // Simulate database write latency
            
            customer.CreatedAt = DateTime.UtcNow;
            customer.UpdatedAt = null;
            
            _context.Customers.Add(customer);
            await _context.SaveChangesAsync();
            
            return customer;
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<Customer> UpdateCustomerAsync(Customer customer)
    {
        await SimulateFailure("write");
        CheckConcurrentClients();
        try
        {
            await Task.Delay(100); // Simulate database write latency
            
            var existingCustomer = await _context.Customers.FindAsync(customer.Id);
            if (existingCustomer == null)
            {
                throw new InvalidOperationException($"Customer with ID {customer.Id} not found");
            }
            
            existingCustomer.Name = customer.Name;
            existingCustomer.Email = customer.Email;
            existingCustomer.Phone = customer.Phone;
            existingCustomer.Address = customer.Address;
            existingCustomer.UpdatedAt = DateTime.UtcNow;
            
            await _context.SaveChangesAsync();
            
            return existingCustomer;
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<bool> DeleteCustomerAsync(int id)
    {
        await SimulateFailure("write");
        CheckConcurrentClients();
        try
        {
            await Task.Delay(50); // Simulate database latency
            
            var customer = await _context.Customers.FindAsync(id);
            if (customer == null)
            {
                return false;
            }
            
            _context.Customers.Remove(customer);
            await _context.SaveChangesAsync();
            
            return true;
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<IEnumerable<Customer>> GetAllCustomersAsync()
    {
        await SimulateFailure("read");
        CheckConcurrentClients();
        try
        {
            await Task.Delay(200); // Simulate full table scan
            return await _context.Customers.OrderBy(c => c.Id).ToListAsync();
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
}