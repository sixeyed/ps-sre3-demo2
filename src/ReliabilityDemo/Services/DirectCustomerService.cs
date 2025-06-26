using Microsoft.AspNetCore.Mvc;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.DataStore.Services;
using ReliabilityDemo.Models;

namespace ReliabilityDemo.Services;

public class DirectCustomerService : ICustomerOperationService
{
    private readonly IDataStore _dataStore;
    private readonly IDistributedCache _cache;
    private readonly ILogger<DirectCustomerService> _logger;

    public DirectCustomerService(
        IDataStore dataStore,
        IDistributedCache cache,
        ILogger<DirectCustomerService> logger)
    {
        _dataStore = dataStore;
        _cache = cache;
        _logger = logger;
    }

    public async Task<IActionResult> CreateCustomerAsync(CreateCustomerRequest request, string correlationId)
    {
        _logger.LogDebug("Creating customer directly: {Name}, {Email}", request.Name, request.Email);
        
        try
        {
            var customer = new Customer
            {
                Name = request.Name,
                Email = request.Email,
                Phone = request.Phone,
                Address = request.Address,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            // Create customer directly in data store
            var createdCustomer = await _dataStore.CreateCustomerAsync(customer);
            
            // Invalidate cache since data changed
            await _cache.InvalidateAllCustomersAsync();
            _logger.LogDebug("Created customer {CustomerId} directly and invalidated cache", createdCustomer.Id);

            return new CreatedResult($"/api/customers/{createdCustomer.Id}", createdCustomer);
        }
        catch (TimeoutException ex)
        {
            return new StatusCodeResult(408) { };
        }
        catch (InvalidOperationException ex)
        {
            return new StatusCodeResult(503) { };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating customer directly");
            return new StatusCodeResult(500) { };
        }
    }

    public async Task<IActionResult> UpdateCustomerAsync(int id, UpdateCustomerRequest request, string correlationId)
    {
        _logger.LogDebug("Updating customer directly with ID: {Id}", id);
        
        try
        {
            var customer = new Customer
            {
                Id = id,
                Name = request.Name,
                Email = request.Email,
                Phone = request.Phone,
                Address = request.Address,
                UpdatedAt = DateTime.UtcNow
            };

            // Update customer directly in data store
            var updatedCustomer = await _dataStore.UpdateCustomerAsync(customer);
            
            // Invalidate cache since data changed
            await _cache.InvalidateCustomerAsync(id);
            await _cache.InvalidateAllCustomersAsync();
            _logger.LogDebug("Updated customer {CustomerId} directly and invalidated cache", id);

            return new OkObjectResult(updatedCustomer);
        }
        catch (TimeoutException ex)
        {
            return new StatusCodeResult(408) { };
        }
        catch (InvalidOperationException ex)
        {
            return new StatusCodeResult(503) { };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating customer {CustomerId} directly", id);
            return new StatusCodeResult(500) { };
        }
    }

    public async Task<IActionResult> DeleteCustomerAsync(int id, string correlationId)
    {
        _logger.LogDebug("Deleting customer directly with ID: {Id}", id);
        
        try
        {
            // Delete customer directly from data store
            var deleted = await _dataStore.DeleteCustomerAsync(id);
            
            if (!deleted)
            {
                return new NotFoundObjectResult(new { error = $"Customer with ID {id} not found" });
            }
            
            // Invalidate cache since data changed
            await _cache.InvalidateCustomerAsync(id);
            await _cache.InvalidateAllCustomersAsync();
            _logger.LogDebug("Deleted customer {CustomerId} directly and invalidated cache", id);

            return new NoContentResult();
        }
        catch (TimeoutException ex)
        {
            return new StatusCodeResult(408) { };
        }
        catch (InvalidOperationException ex)
        {
            return new StatusCodeResult(503) { };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting customer {CustomerId} directly", id);
            return new StatusCodeResult(500) { };
        }
    }
}