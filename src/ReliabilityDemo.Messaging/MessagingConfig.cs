namespace ReliabilityDemo.Messaging;

public class MessagingConfig
{
    public string CreateCustomerQueueName { get; set; } = "customer_create_queue";
    public string UpdateCustomerQueueName { get; set; } = "customer_update_queue";
    public string DeleteCustomerQueueName { get; set; } = "customer_delete_queue";
    public int RetryAttempts { get; set; } = 3;
    public int RetryDelayMs { get; set; } = 1000;
}