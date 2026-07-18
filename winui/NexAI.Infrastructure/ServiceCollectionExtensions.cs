using Microsoft.Extensions.DependencyInjection;
using NexAI.Core.Auth;
using NexAI.Core.Chat;
using NexAI.Core.Notes;
using NexAI.Core.Settings;
using NexAI.Core.Sync;
using NexAI.Core.Tools;
using NexAI.Infrastructure.Auth;
using NexAI.Infrastructure.Chat;
using NexAI.Infrastructure.Media;
using NexAI.Infrastructure.Storage;
using NexAI.Infrastructure.Sync;
using NexAI.Infrastructure.Tools;

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
        services.AddSingleton<HttpClient>();
        services.AddSingleton<IChatStreamingClient, OpenAiCompatibleChatClient>();
        services.AddSingleton<IShortUrlClient, MmpShortUrlClient>();
        services.AddSingleton<IArtifactsClient, NexaiArtifactsClient>();
        services.AddSingleton<IImageGenerationClient, OpenAiImageGenerationClient>();
        services.AddSingleton<IMediaToolService, FfmpegMediaToolService>();
        services.AddSingleton<ITranslationClient, DeepLxTranslationClient>();
        services.AddSingleton<ITranslationHistoryStore, JsonTranslationHistoryStore>();
        services.AddSingleton<IShortUrlHistoryStore, JsonShortUrlHistoryStore>();
        services.AddSingleton<IPasswordVaultStore, ProtectedPasswordVaultStore>();
        return services;
    }
}
