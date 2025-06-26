using Microsoft.AspNetCore.Mvc;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.DataStore.Services;
using ReliabilityDemo.Models;
using ReliabilityDemo.Services;
using ReliabilityDemo.Messaging;

namespace ReliabilityDemo.Controllers;

[ApiController]
[Route("api/customers")]
public class DataController : ControllerBase
{
    private readonly IDataStore _dataStore;
    private readonly IDistributedCache _cache;
    private readonly ICustomerOperationService _customerOperationService;
    private readonly ILogger<DataController> _logger;
    private readonly string _dataStoreType;

    public DataController(IDataStore dataStore, IDistributedCache cache, ICustomerOperationService customerOperationService, ILogger<DataController> logger)
    {
        _dataStore = dataStore;
        _cache = cache;
        _customerOperationService = customerOperationService;
        _logger = logger;
        _dataStoreType = dataStore.GetType().Name;
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetCustomer(int id)
    {
        _logger.LogDebug("Getting customer with ID: {Id} using {DataStore}", id, _dataStoreType);
        try
        {
            // Try cache first
            var cachedCustomer = await _cache.GetCustomerAsync(id);
            if (cachedCustomer != null)
            {
                _logger.LogDebug("Customer {Id} found in cache", id);
                return Ok(cachedCustomer);
            }
            
            // Cache miss - get from data store
            var customer = await _dataStore.GetCustomerAsync(id);
            
            if (customer == null)
                return NotFound(new { error = $"Customer with ID {id} not found" });
            
            // Cache the result
            await _cache.SetCustomerAsync(customer);
            _logger.LogDebug("Customer {Id} retrieved from {DataStore} and cached", id, _dataStoreType);
                
            return Ok(customer);
        }
        catch (TimeoutException ex)
        {
            return StatusCode(408, new { error = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(503, new { error = ex.Message });
        }
    }

    [HttpGet("email/{email}")]
    public async Task<IActionResult> GetCustomerByEmail(string email)
    {
        _logger.LogDebug("Getting customer with email: {Email} using {DataStore}", email, _dataStoreType);
        try
        {
            // Try cache first
            var cachedCustomer = await _cache.GetCustomerByEmailAsync(email);
            if (cachedCustomer != null)
            {
                _logger.LogDebug("Customer with email {Email} found in cache", email);
                return Ok(cachedCustomer);
            }
            
            // Cache miss - get from data store
            var customer = await _dataStore.GetCustomerByEmailAsync(email);
            
            if (customer == null)
                return NotFound(new { error = $"Customer with email {email} not found" });
            
            // Cache the result
            await _cache.SetCustomerAsync(customer);
            _logger.LogDebug("Customer with email {Email} retrieved from {DataStore} and cached", email, _dataStoreType);
                
            return Ok(customer);
        }
        catch (TimeoutException ex)
        {
            return StatusCode(408, new { error = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(503, new { error = ex.Message });
        }
    }

    [HttpPost]
    public async Task<IActionResult> CreateCustomer([FromBody] CreateCustomerRequest request)
    {
        return await _customerOperationService.CreateCustomerAsync(request, HttpContext.TraceIdentifier);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCustomer(int id, [FromBody] UpdateCustomerRequest request)
    {
        return await _customerOperationService.UpdateCustomerAsync(id, request, HttpContext.TraceIdentifier);
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteCustomer(int id)
    {
        return await _customerOperationService.DeleteCustomerAsync(id, HttpContext.TraceIdentifier);
    }

    [HttpGet]
    public async Task<IActionResult> GetAllCustomers()
    {
        _logger.LogDebug("Getting all customers using {DataStore}", _dataStoreType);
        try
        {
            // Try cache first
            var cachedCustomers = await _cache.GetAllCustomersAsync();
            if (cachedCustomers != null)
            {
                _logger.LogDebug("All customers found in cache");
                return Ok(cachedCustomers);
            }
            
            // Cache miss - get from data store
            var customers = await _dataStore.GetAllCustomersAsync();
            
            // Cache the result
            await _cache.SetAllCustomersAsync(customers);
            _logger.LogDebug("All customers retrieved from {DataStore} and cached", _dataStoreType);
            
            return Ok(customers);
        }
        catch (TimeoutException ex)
        {
            return StatusCode(408, new { error = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(503, new { error = ex.Message });
        }
    }
}