using ReliabilityDemo.DataStore.Models;

namespace ReliabilityDemo.DataStore.Services;

public interface IDataStore
{
    Task<Customer?> GetCustomerAsync(int id);
    Task<Customer?> GetCustomerByEmailAsync(string email);
    Task<Customer> CreateCustomerAsync(Customer customer);
    Task<Customer> UpdateCustomerAsync(Customer customer);
    Task<bool> DeleteCustomerAsync(int id);
    Task<IEnumerable<Customer>> GetAllCustomersAsync();
}