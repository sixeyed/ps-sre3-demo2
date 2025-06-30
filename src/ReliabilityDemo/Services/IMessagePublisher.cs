using ReliabilityDemo.Messaging;

namespace ReliabilityDemo.Services;

public interface IMessagePublisher
{
    Task PublishCreateCustomerAsync(CreateCustomerMessage message);
    Task PublishUpdateCustomerAsync(UpdateCustomerMessage message);
    Task PublishDeleteCustomerAsync(DeleteCustomerMessage message);
}