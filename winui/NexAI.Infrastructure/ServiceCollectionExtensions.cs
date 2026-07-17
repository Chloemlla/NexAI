using Microsoft.Extensions.DependencyInjection;
using NexAI.Core.Auth;
using NexAI.Core.Chat;
using NexAI.Core.Migration;
using NexAI.Core.Notes;
using NexAI.Core.Settings;
using NexAI.Core.Sync;
using NexAI.Infrastructure.Auth;
using NexAI.Infrastructure.Chat;
using NexAI.Infrastructure.Migration;
using NexAI.Infrastructure.Storage;
using NexAI.Infrastructure.Sync;

namespace NexAI.Infrastructure;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddNexAIInfrastructure(this IServiceCollection services)
    {
        services.AddSingleton<ISettingsStore, JsonSettingsStore>();
        services.AddSingleton<IConversationStore, JsonConversationStore>();
        services.AddSingleton<INotesStore, JsonNotesStore>();
        services.AddSingleton<IAuthSessionStore, JsonAuthSessionStore>();
        services.AddSingleton<IAuthClient, NexaiAuthClient>();
        services.AddSingleton<ISyncCrypto, AesGcmSyncCrypto>();
        services.AddSingleton<ISyncService, NexaiSyncService>();
        services.AddSingleton<IFlutterDataMigrator, FlutterDataMigrator>();
        services.AddSingleton<HttpClient>();
        services.AddSingleton<IChatStreamingClient, OpenAiCompatibleChatClient>();
        return services;
    }
}
