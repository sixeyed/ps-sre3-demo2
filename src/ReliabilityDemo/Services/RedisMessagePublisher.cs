using Microsoft.Extensions.Options;
using ReliabilityDemo.Messaging;
using StackExchange.Redis;
using System.Text.Json;

namespace ReliabilityDemo.Services;

public class RedisMessagePublisher : IMessagePublisher
{
    private readonly IDatabase _database;
    private readonly MessagingConfig _config;
    private readonly ILogger<RedisMessagePublisher> _logger;
    
    public RedisMessagePublisher(IConnectionMultiplexer redis, IOptions<MessagingConfig> config, ILogger<RedisMessagePublisher> logger)
    {
        _database = redis.GetDatabase();
        _config = config.Value;
        _logger = logger;
    }
    
    public async Task PublishCreateCustomerAsync(CreateCustomerMessage message)
    {
        await PublishMessageAsync(message, _config.CreateCustomerQueueName, "Create");
    }

    public async Task PublishUpdateCustomerAsync(UpdateCustomerMessage message)
    {
        await PublishMessageAsync(message, _config.UpdateCustomerQueueName, "Update");
    }

    public async Task PublishDeleteCustomerAsync(DeleteCustomerMessage message)
    {
        await PublishMessageAsync(message, _config.DeleteCustomerQueueName, "Delete");
    }

    private async Task PublishMessageAsync<T>(T message, string queueName, string operationType) where T : CustomerMessageBase
    {
        try
        {
            var json = JsonSerializer.Serialize(message);
            // Use Redis List (LPUSH) to create a queue where only one worker processes each message
            await _database.ListLeftPushAsync(queueName, json);
            
            _logger.LogDebug("Queued {OperationType} customer message {MessageId} to queue {QueueName}", 
                operationType, message.MessageId, queueName);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to queue {OperationType} customer message {MessageId} to queue {QueueName}", 
                operationType, message.MessageId, queueName);
            throw;
        }
    }
}