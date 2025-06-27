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
    // Event IDs for structured logging
    private static class EventIds
    {
        public static readonly EventId CustomerFetchRequest = new(4001, "CustomerFetchRequest");
        public static readonly EventId CustomerServedCache = new(4002, "CustomerServedCache");
        public static readonly EventId CustomerServedDb = new(4003, "CustomerServedDb");
        public static readonly EventId CustomerFetchEmailRequest = new(4004, "CustomerFetchEmailRequest");
        public static readonly EventId CustomerServedCacheEmail = new(4005, "CustomerServedCacheEmail");
        public static readonly EventId CustomerServedDbEmail = new(4006, "CustomerServedDbEmail");
        public static readonly EventId CustomerFetchAllRequest = new(4007, "CustomerFetchAllRequest");
        public static readonly EventId CustomerServedAllCache = new(4008, "CustomerServedAllCache");
        public static readonly EventId CustomerServedAllDb = new(4009, "CustomerServedAllDb");
    }
    
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
        _logger.LogInformation(EventIds.CustomerFetchRequest, "Customer fetch requested | CustomerId: {Id} | Provider: {DataStore}", id, _dataStoreType);
        try
        {
            // Try cache first
            var cachedCustomer = await _cache.GetCustomerAsync(id);
            if (cachedCustomer != null)
            {
                _logger.LogInformation(EventIds.CustomerServedCache, "Customer served from cache | CustomerId: {Id} | Provider: {DataStore}", id, _dataStoreType);
                return Ok(cachedCustomer);
            }
            
            // Cache miss - get from data store
            var customer = await _dataStore.GetCustomerAsync(id);
            
            if (customer == null)
                return NotFound(new { error = $"Customer with ID {id} not found" });
            
            // Cache the result
            await _cache.SetCustomerAsync(customer);
            _logger.LogInformation(EventIds.CustomerServedDb, "Customer served from database | CustomerId: {Id} | Provider: {DataStore}", id, _dataStoreType);
                
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
        _logger.LogInformation(EventIds.CustomerFetchEmailRequest, "Customer fetch by email requested | Email: {Email} | Provider: {DataStore}", email, _dataStoreType);
        try
        {
            // Try cache first
            var cachedCustomer = await _cache.GetCustomerByEmailAsync(email);
            if (cachedCustomer != null)
            {
                _logger.LogInformation(EventIds.CustomerServedCacheEmail, "Customer served from cache by email | Email: {Email} | Provider: {DataStore}", email, _dataStoreType);
                return Ok(cachedCustomer);
            }
            
            // Cache miss - get from data store
            var customer = await _dataStore.GetCustomerByEmailAsync(email);
            
            if (customer == null)
                return NotFound(new { error = $"Customer with email {email} not found" });
            
            // Cache the result
            await _cache.SetCustomerAsync(customer);
            _logger.LogInformation(EventIds.CustomerServedDbEmail, "Customer served from database by email | Email: {Email} | Provider: {DataStore}", email, _dataStoreType);
                
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
        _logger.LogInformation(EventIds.CustomerFetchAllRequest, "All customers fetch requested | Provider: {DataStore}", _dataStoreType);
        try
        {
            // Try cache first
            var cachedCustomers = await _cache.GetAllCustomersAsync();
            if (cachedCustomers != null)
            {
                _logger.LogInformation(EventIds.CustomerServedAllCache, "All customers served from cache | Provider: {DataStore}", _dataStoreType);
                return Ok(cachedCustomers);
            }
            
            // Cache miss - get from data store
            var customers = await _dataStore.GetAllCustomersAsync();
            
            // Cache the result
            await _cache.SetAllCustomersAsync(customers);
            _logger.LogInformation(EventIds.CustomerServedAllDb, "All customers served from database | Provider: {DataStore}", _dataStoreType);
            
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