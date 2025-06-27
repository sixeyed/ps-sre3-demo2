using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using ReliabilityDemo.DataStore.Data;
using ReliabilityDemo.DataStore.Models;

namespace ReliabilityDemo.DataStore.Services;

public class SqlServerDataStore : IDataStore
{
    // Event IDs for structured logging
    private static class EventIds
    {
        public static readonly EventId ConnectionFailure = new(1001, "ConnectionFailure");
        public static readonly EventId ReadTimeout = new(1002, "ReadTimeout");
        public static readonly EventId WriteTimeout = new(1003, "WriteTimeout");
        public static readonly EventId SlowResponse = new(1004, "SlowResponse");
        public static readonly EventId ClientLimitExceeded = new(1005, "ClientLimitExceeded");
        public static readonly EventId CustomerFetchDb = new(2001, "CustomerFetchDb");
        public static readonly EventId CustomerNotFoundDb = new(2002, "CustomerNotFoundDb");
        public static readonly EventId CustomerFetchDbEmail = new(2003, "CustomerFetchDbEmail");
        public static readonly EventId CustomerNotFoundDbEmail = new(2004, "CustomerNotFoundDbEmail");
        public static readonly EventId CustomerCreatedDb = new(2005, "CustomerCreatedDb");
        public static readonly EventId CustomerUpdatedDb = new(2006, "CustomerUpdatedDb");
        public static readonly EventId CustomerFetchAllDb = new(2007, "CustomerFetchAllDb");
        public static readonly EventId CustomerClearAllDb = new(2008, "CustomerClearAllDb");
        public static readonly EventId CustomerCountDb = new(2009, "CustomerCountDb");
    }
    
    private readonly ReliabilityDemoContext _context;
    private readonly SqlServerDataStoreConfig _config;
    private readonly FailureConfig _failureConfig;
    private readonly Random _random = new();
    private readonly ILogger<SqlServerDataStore> _logger;
    private readonly string _dataStoreType;
    private static int _concurrentClients = 0;
    private static readonly object _lock = new object();
    
    public SqlServerDataStore(ReliabilityDemoContext context, IOptions<SqlServerDataStoreConfig> config, IOptions<FailureConfig> failureConfig, ILogger<SqlServerDataStore> logger)
    {
        _context = context;
        _config = config.Value;
        _failureConfig = failureConfig.Value;
        _logger = logger;
        _dataStoreType = GetType().Name;
    }
    
    private async Task SimulateFailure(string operation)
    {
        if (!_failureConfig.Enabled)
            return;

        // Simulate connection failures
        if (ShouldFail(_failureConfig.ConnectionFailureRate))
        {
            _logger.LogWarning(EventIds.ConnectionFailure, "Connection failure | Operation: {Operation} | Provider: {DataStoreProvider}", operation, _dataStoreType);
            throw new InvalidOperationException("Connection failed - service unavailable");
        }

        // Simulate read timeouts
        if (operation == "read" && ShouldFail(_failureConfig.ReadTimeoutRate))
        {
            _logger.LogWarning(EventIds.ReadTimeout, "Read timeout | Operation: {Operation} | Delay: {DelayMs}ms | Provider: {DataStoreProvider}", operation, _failureConfig.ReadTimeoutMs, _dataStoreType);
            await Task.Delay(_failureConfig.ReadTimeoutMs);
            throw new TimeoutException("Read operation timed out");
        }

        // Simulate write timeouts
        if (operation == "write" && ShouldFail(_failureConfig.WriteTimeoutRate))
        {
            _logger.LogWarning(EventIds.WriteTimeout, "Write timeout | Operation: {Operation} | Delay: {DelayMs}ms | Provider: {DataStoreProvider}", operation, _failureConfig.WriteTimeoutMs, _dataStoreType);
            await Task.Delay(_failureConfig.WriteTimeoutMs);
            throw new TimeoutException("Write operation timed out");
        }

        // Simulate slow responses
        if (ShouldFail(_failureConfig.SlowResponseRate))
        {
            _logger.LogWarning(EventIds.SlowResponse, "Pausing to reduce database load | Operation: {Operation} | Delay: {DelayMs}ms | Provider: {DataStoreProvider}", operation, _failureConfig.SlowResponseDelayMs, _dataStoreType);
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
                _logger.LogError(EventIds.ClientLimitExceeded, "Throttling to reduce database load | Current: {Current} | Max: {Max} | Provider: {DataStoreProvider}", _concurrentClients, _config.MaxConcurrentClients, _dataStoreType);
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
            var customer = await _context.Customers.FindAsync(id);
            
            if (customer != null)
            {
                _logger.LogInformation(EventIds.CustomerFetchDb, "Customer retrieved from database | CustomerId: {CustomerId} | Email: {EmailAddress} | Provider: {DataStoreProvider}", customer.Id, customer.Email, _dataStoreType);
            }
            else
            {
                _logger.LogInformation(EventIds.CustomerNotFoundDb, "Customer not found in database | CustomerId: {CustomerId} | Provider: {DataStoreProvider}", id, _dataStoreType);
            }
            
            return customer;
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<Customer?> GetCustomerByEmailAsync(string email)
    {
        await SimulateFailure("read");
        CheckConcurrentClients();
        try
        {
            await Task.Delay(50); // Simulate database latency
            var customer = await _context.Customers.FirstOrDefaultAsync(c => c.Email == email);
            
            if (customer != null)
            {
                _logger.LogInformation(EventIds.CustomerFetchDbEmail, "Customer retrieved by email from database | CustomerId: {CustomerId} | Email: {EmailAddress} | Provider: {DataStoreProvider}", customer.Id, customer.Email, _dataStoreType);
            }
            else
            {
                _logger.LogInformation(EventIds.CustomerNotFoundDbEmail, "Customer not found by email in database | Email: {EmailAddress} | Provider: {DataStoreProvider}", email, _dataStoreType);
            }
            
            return customer;
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
            _logger.LogInformation(EventIds.CustomerCreatedDb, "Customer created in database | CustomerId: {CustomerId} | Email: {EmailAddress} | Provider: {DataStoreProvider}", customer.Id, customer.Email, _dataStoreType);
            
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
            _logger.LogInformation(EventIds.CustomerUpdatedDb, "Customer updated in database | CustomerId: {CustomerId} | Email: {EmailAddress} | Provider: {DataStoreProvider}", existingCustomer.Id, existingCustomer.Email, _dataStoreType);
            
            return existingCustomer;
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
    
    public async Task<bool> DeleteCustomerAsync(int id)
    {
        throw new NotImplementedException();
    }
    
    public async Task<IEnumerable<Customer>> GetAllCustomersAsync()
    {
        await SimulateFailure("read");
        CheckConcurrentClients();
        try
        {
            await Task.Delay(200); // Simulate full table scan
            var customers = await _context.Customers.OrderBy(c => c.Id).ToListAsync();
            _logger.LogInformation(EventIds.CustomerFetchAllDb, "All customers fetched from database | Count: {CustomerCount} | Provider: {DataStoreProvider}", customers.Count, _dataStoreType);
            return customers;    
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }

    public async Task ClearAllCustomersAsync()
    {
        await SimulateFailure("write");
        CheckConcurrentClients();
        try
        {
            await Task.Delay(150); // Simulate bulk delete operation
            
            // Use raw SQL for better performance on large datasets
            await _context.Database.ExecuteSqlRawAsync("TRUNCATE TABLE Customers");
            _logger.LogInformation(EventIds.CustomerClearAllDb, "All customers cleared from database | Provider: {DataStoreProvider}", _dataStoreType);
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }

    public async Task<int> GetCustomerCountAsync()
    {
        await SimulateFailure("read");
        CheckConcurrentClients();
        try
        {
            await Task.Delay(25); // Simulate count query
            var count = await _context.Customers.CountAsync();
            _logger.LogInformation(EventIds.CustomerCountDb, "Customer count retrieved | Count: {Count} | Provider: {DataStoreProvider}", count, _dataStoreType);
            return count;
        }
        finally
        {
            ReleaseConcurrentClient();
        }
    }
}