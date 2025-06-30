using ReliabilityDemo.DataStore.Models;

namespace ReliabilityDemo.DataStore.Services;

public interface IDistributedCache
{
    Task<Customer?> GetCustomerAsync(int id);
    Task<Customer?> GetCustomerByEmailAsync(string email);
    Task<IEnumerable<Customer>?> GetAllCustomersAsync();
    Task SetCustomerAsync(Customer customer);
    Task SetAllCustomersAsync(IEnumerable<Customer> customers);
    Task InvalidateCustomerAsync(int id);
    Task InvalidateCustomerByEmailAsync(string email);
    Task InvalidateAllCustomersAsync();
    Task InvalidateAllAsync();
    Task<object> GetCacheStatusAsync();
}