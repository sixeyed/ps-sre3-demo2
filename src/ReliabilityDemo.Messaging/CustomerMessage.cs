using ReliabilityDemo.DataStore.Models;

namespace ReliabilityDemo.Messaging;

public abstract class CustomerMessageBase
{
    public string MessageId { get; set; } = Guid.NewGuid().ToString();
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public string? CorrelationId { get; set; }
}

public class CreateCustomerMessage : CustomerMessageBase
{
    public Customer Customer { get; set; } = null!;
}

public class UpdateCustomerMessage : CustomerMessageBase
{
    public Customer Customer { get; set; } = null!;
}

public class DeleteCustomerMessage : CustomerMessageBase
{
    public int CustomerId { get; set; }
}