using ReliabilityDemo.Models;

namespace ReliabilityDemo.Services;

public interface IDataStore
{
    Task<Customer?> GetCustomerAsync(int id);
    Task<Customer> CreateCustomerAsync(Customer customer);
    Task<Customer> UpdateCustomerAsync(Customer customer);
    Task<bool> DeleteCustomerAsync(int id);
    Task<IEnumerable<Customer>> GetAllCustomersAsync();
}