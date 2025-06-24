using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using ReliabilityDemo.Data;
using ReliabilityDemo.Models;

namespace ReliabilityDemo.Services;

public class SqlServerDataStore : IDataStore
{
    private readonly ReliabilityDemoContext _context;
    private readonly SqlServerDataStoreConfig _config;
    private static int _concurrentClients = 0;
    private static readonly object _lock = new object();
    
    public SqlServerDataStore(ReliabilityDemoContext context, IOptions<SqlServerDataStoreConfig> config)
    {
        _context = context;
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
            return await _context.Customers.FindAsync(id);
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