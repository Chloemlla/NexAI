using Microsoft.Extensions.DependencyInjection;
using NexAI.Core.Settings;
using NexAI.Infrastructure.Storage;

namespace NexAI.Infrastructure;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddNexAIInfrastructure(this IServiceCollection services)
    {
        services.AddSingleton<ISettingsStore, JsonSettingsStore>();
        return services;
    }
}
