using Microsoft.Extensions.Options;
using ReliabilityDemo.DataStore.Services;
using ReliabilityDemo.Messaging;
using StackExchange.Redis;
using System.Text.Json;

namespace ReliabilityDemo.Worker;

public class CustomerMessageWorker : BackgroundService
{
    private readonly IConnectionMultiplexer _redis;
    private readonly IServiceProvider _serviceProvider;
    private readonly MessagingConfig _config;
    private readonly ILogger<CustomerMessageWorker> _logger;
    
    public CustomerMessageWorker(
        IConnectionMultiplexer redis, 
        IServiceProvider serviceProvider,
        IOptions<MessagingConfig> config,
        ILogger<CustomerMessageWorker> logger)
    {
        _redis = redis;
        _serviceProvider = serviceProvider;
        _config = config.Value;
        _logger = logger;
    }
    
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("CustomerMessageWorker starting - processing queues: Create={CreateQueue}, Update={UpdateQueue}, Delete={DeleteQueue}", 
            _config.CreateCustomerQueueName, _config.UpdateCustomerQueueName, _config.DeleteCustomerQueueName);
        
        var database = _redis.GetDatabase();
        
        // Process messages from Redis queues using parallel tasks
        var tasks = new[]
        {
            ProcessQueueAsync(database, _config.CreateCustomerQueueName, ProcessCreateCustomerMessage, "Create", stoppingToken),
            ProcessQueueAsync(database, _config.UpdateCustomerQueueName, ProcessUpdateCustomerMessage, "Update", stoppingToken),
            ProcessQueueAsync(database, _config.DeleteCustomerQueueName, ProcessDeleteCustomerMessage, "Delete", stoppingToken)
        };
        
        _logger.LogInformation("CustomerMessageWorker started processing all queues");
        
        // Wait for any task to complete (shouldn't happen unless cancellation or error)
        await Task.WhenAny(tasks);
        
        _logger.LogInformation("CustomerMessageWorker stopping...");
    }
    
    private async Task ProcessQueueAsync(IDatabase database, string queueName, Func<string, Task> messageProcessor, string operationType, CancellationToken stoppingToken)
    {
        _logger.LogInformation("Starting queue processor for {OperationType} on queue {QueueName}", operationType, queueName);
        
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // Use RPOP to get message from queue (non-blocking)
                var result = await database.ListRightPopAsync(queueName);
                
                if (result.HasValue)
                {
                    _logger.LogDebug("Received {OperationType} message from queue {QueueName}", operationType, queueName);
                    await messageProcessor(result!);
                }
                else
                {
                    // If no message, wait a bit before checking again
                    await Task.Delay(1000, stoppingToken);
                }
            }
            catch (OperationCanceledException)
            {
                // Expected during shutdown
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing {OperationType} queue {QueueName}", operationType, queueName);
                // Wait a bit before retrying to avoid tight error loops
                await Task.Delay(1000, stoppingToken);
            }
        }
        
        _logger.LogInformation("Queue processor for {OperationType} on queue {QueueName} stopped", operationType, queueName);
    }
    
    private async Task ProcessCreateCustomerMessage(string messageJson)
    {
        CreateCustomerMessage? message = null;
        
        try
        {
            message = JsonSerializer.Deserialize<CreateCustomerMessage>(messageJson);
            if (message == null)
            {
                _logger.LogWarning("Received null create customer message or failed to deserialize");
                return;
            }
            
            _logger.LogDebug("Processing create customer message {MessageId}", message.MessageId);
            
            using var scope = _serviceProvider.CreateScope();
            var dataStore = scope.ServiceProvider.GetRequiredService<IDataStore>();
            
            await ProcessWithRetry(async () => await dataStore.CreateCustomerAsync(message.Customer), message.MessageId, "Create");
            
            _logger.LogDebug("Successfully processed create customer message {MessageId}", message.MessageId);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to deserialize create customer message: {Message}", messageJson);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process create customer message {MessageId}", message?.MessageId ?? "unknown");
        }
    }
    
    private async Task ProcessUpdateCustomerMessage(string messageJson)
    {
        UpdateCustomerMessage? message = null;
        
        try
        {
            message = JsonSerializer.Deserialize<UpdateCustomerMessage>(messageJson);
            if (message == null)
            {
                _logger.LogWarning("Received null update customer message or failed to deserialize");
                return;
            }
            
            _logger.LogDebug("Processing update customer message {MessageId}", message.MessageId);
            
            using var scope = _serviceProvider.CreateScope();
            var dataStore = scope.ServiceProvider.GetRequiredService<IDataStore>();
            
            await ProcessWithRetry(async () => await dataStore.UpdateCustomerAsync(message.Customer), message.MessageId, "Update");
            
            _logger.LogDebug("Successfully processed update customer message {MessageId}", message.MessageId);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to deserialize update customer message: {Message}", messageJson);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process update customer message {MessageId}", message?.MessageId ?? "unknown");
        }
    }
    
    private async Task ProcessDeleteCustomerMessage(string messageJson)
    {
        DeleteCustomerMessage? message = null;
        
        try
        {
            message = JsonSerializer.Deserialize<DeleteCustomerMessage>(messageJson);
            if (message == null)
            {
                _logger.LogWarning("Received null delete customer message or failed to deserialize");
                return;
            }
            
            _logger.LogDebug("Processing delete customer message {MessageId}", message.MessageId);
            
            using var scope = _serviceProvider.CreateScope();
            var dataStore = scope.ServiceProvider.GetRequiredService<IDataStore>();
            
            await ProcessWithRetry(async () => 
            {
                var deleted = await dataStore.DeleteCustomerAsync(message.CustomerId);
                if (!deleted)
                {
                    _logger.LogWarning("Customer {CustomerId} not found for deletion from message {MessageId}", 
                        message.CustomerId, message.MessageId);
                }
            }, message.MessageId, "Delete");
            
            _logger.LogDebug("Successfully processed delete customer message {MessageId}", message.MessageId);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to deserialize delete customer message: {Message}", messageJson);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to process delete customer message {MessageId}", message?.MessageId ?? "unknown");
        }
    }
    
    private async Task ProcessWithRetry(Func<Task> operation, string messageId, string operationType)
    {
        var attempt = 0;
        
        while (attempt < _config.RetryAttempts)
        {
            try
            {
                await operation();
                return; // Success
            }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException ex) when (ex.InnerException?.Message?.Contains("duplicate key") == true)
            {
                // Duplicate key errors are not transient - don't retry
                _logger.LogWarning("Duplicate key error for {OperationType} message {MessageId} - skipping retry: {Error}", 
                    operationType, messageId, ex.InnerException?.Message);
                return;
            }
            catch (Exception ex)
            {
                attempt++;
                _logger.LogWarning(ex, "Attempt {Attempt}/{MaxAttempts} failed for {OperationType} message {MessageId}", 
                    attempt, _config.RetryAttempts, operationType, messageId);
                
                if (attempt >= _config.RetryAttempts)
                {
                    _logger.LogError(ex, "All retry attempts failed for {OperationType} message {MessageId}", operationType, messageId);
                    throw;
                }
                
                await Task.Delay(_config.RetryDelayMs * attempt); // Exponential backoff
            }
        }
    }
    
    
    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("CustomerMessageWorker stopping queue processing...");
        await base.StopAsync(cancellationToken);
    }
}