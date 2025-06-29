using Microsoft.AspNetCore.Mvc;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.Models;
using ReliabilityDemo.Messaging;

namespace ReliabilityDemo.Services;

public class AsyncCustomerService : ICustomerOperationService
{
    private readonly IMessagePublisher _messagePublisher;
    private readonly ILogger<AsyncCustomerService> _logger;

    public AsyncCustomerService(
        IMessagePublisher messagePublisher,
        ILogger<AsyncCustomerService> logger)
    {
        _messagePublisher = messagePublisher;
        _logger = logger;
    }

    public async Task<IActionResult> CreateCustomerAsync(CreateCustomerRequest request, string correlationId)
    {
        _logger.LogDebug("Creating customer via messaging: {Name}, {Email}", request.Name, request.Email);
        
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

            // Don't set ID - let the data store auto-generate it
            // ID will be 0, which signals to the data store to auto-generate

            // Publish message for async processing
            var message = new CreateCustomerMessage
            {
                Customer = customer,
                CorrelationId = correlationId
            };

            await _messagePublisher.PublishCreateCustomerAsync(message);

            _logger.LogDebug("Published create message {MessageId} for customer {Name}", 
                message.MessageId, customer.Name);

            return new AcceptedResult("/api/customers", new { 
                message = "Customer creation request accepted and will be processed asynchronously",
                messageId = message.MessageId,
                customer = customer
            });
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
            _logger.LogError(ex, "Error publishing create customer message");
            return new StatusCodeResult(500) { };
        }
    }

    public async Task<IActionResult> UpdateCustomerAsync(int id, UpdateCustomerRequest request, string correlationId)
    {
        _logger.LogDebug("Updating customer via messaging with ID: {Id}", id);
        
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

            // Publish message for async processing
            var message = new UpdateCustomerMessage
            {
                Customer = customer,
                CorrelationId = correlationId
            };

            await _messagePublisher.PublishUpdateCustomerAsync(message);

            _logger.LogDebug("Published update message {MessageId} for customer {Id}", 
                message.MessageId, id);

            return new AcceptedResult($"/api/customers/{id}", new { 
                message = "Customer update request accepted and will be processed asynchronously",
                messageId = message.MessageId,
                customerId = id
            });
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
            _logger.LogError(ex, "Error publishing update customer message for ID {CustomerId}", id);
            return new StatusCodeResult(500) { };
        }
    }

    public async Task<IActionResult> DeleteCustomerAsync(int id, string correlationId)
    {
        _logger.LogDebug("Deleting customer via messaging with ID: {Id}", id);
        
        try
        {
            // Publish message for async processing
            var message = new DeleteCustomerMessage
            {
                CustomerId = id,
                CorrelationId = correlationId
            };

            await _messagePublisher.PublishDeleteCustomerAsync(message);

            _logger.LogDebug("Published delete message {MessageId} for customer {Id}", 
                message.MessageId, id);

            return new AcceptedResult($"/api/customers/{id}", new { 
                message = "Customer deletion request accepted and will be processed asynchronously",
                messageId = message.MessageId,
                customerId = id
            });
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
            _logger.LogError(ex, "Error publishing delete customer message for ID {CustomerId}", id);
            return new StatusCodeResult(500) { };
        }
    }
}