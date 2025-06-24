using Microsoft.AspNetCore.Mvc;
using ReliabilityDemo.Models;
using ReliabilityDemo.Services;

namespace ReliabilityDemo.Controllers;

[ApiController]
[Route("api/customers")]
public class DataController : ControllerBase
{
    private readonly FailureSimulator _failureSimulator;
    private readonly IDataStore _dataStore;
    private readonly ILogger<DataController> _logger;

    public DataController(FailureSimulator failureSimulator, IDataStore dataStore, ILogger<DataController> logger)
    {
        _failureSimulator = failureSimulator;
        _dataStore = dataStore;
        _logger = logger;
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetCustomer(int id)
    {
        _logger.LogDebug("Getting customer with ID: {Id}", id);
        try
        {
            await _failureSimulator.SimulateFailures("read");
            var customer = await _dataStore.GetCustomerAsync(id);
            
            if (customer == null)
                return NotFound(new { error = $"Customer with ID {id} not found" });
                
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
        _logger.LogDebug("Creating customer: {Name}, {Email}", request.Name, request.Email);
        try
        {
            await _failureSimulator.SimulateFailures("write");
            
            var customer = new Customer
            {
                Name = request.Name,
                Email = request.Email,
                Phone = request.Phone,
                Address = request.Address
            };
            
            var createdCustomer = await _dataStore.CreateCustomerAsync(customer);
            return CreatedAtAction(nameof(GetCustomer), new { id = createdCustomer.Id }, createdCustomer);
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

    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCustomer(int id, [FromBody] UpdateCustomerRequest request)
    {
        _logger.LogDebug("Updating customer with ID: {Id}", id);
        try
        {
            await _failureSimulator.SimulateFailures("write");
            
            var customer = new Customer
            {
                Id = id,
                Name = request.Name,
                Email = request.Email,
                Phone = request.Phone,
                Address = request.Address
            };
            
            var updatedCustomer = await _dataStore.UpdateCustomerAsync(customer);
            return Ok(updatedCustomer);
        }
        catch (TimeoutException ex)
        {
            return StatusCode(408, new { error = ex.Message });
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("not found"))
        {
            return NotFound(new { error = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return StatusCode(503, new { error = ex.Message });
        }
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteCustomer(int id)
    {
        _logger.LogDebug("Deleting customer with ID: {Id}", id);
        try
        {
            await _failureSimulator.SimulateFailures("write");
            var deleted = await _dataStore.DeleteCustomerAsync(id);
            
            if (!deleted)
                return NotFound(new { error = $"Customer with ID {id} not found" });
                
            return NoContent();
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

    [HttpGet]
    public async Task<IActionResult> GetAllCustomers()
    {
        _logger.LogDebug("Getting all customers");
        try
        {
            await _failureSimulator.SimulateFailures("read");
            var customers = await _dataStore.GetAllCustomersAsync();
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