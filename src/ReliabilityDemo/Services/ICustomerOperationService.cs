using Microsoft.AspNetCore.Mvc;
using ReliabilityDemo.DataStore.Models;
using ReliabilityDemo.Models;

namespace ReliabilityDemo.Services;

public interface ICustomerOperationService
{
    Task<IActionResult> CreateCustomerAsync(CreateCustomerRequest request, string correlationId);
    Task<IActionResult> UpdateCustomerAsync(int id, UpdateCustomerRequest request, string correlationId);
    Task<IActionResult> DeleteCustomerAsync(int id, string correlationId);
}