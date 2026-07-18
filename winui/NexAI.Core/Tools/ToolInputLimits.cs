namespace NexAI.Core.Tools;

public static class ToolInputLimits
{
    public const int MaxTranslationInputChars = 12_000;
    public const int MaxBase64InputChars = Base64Codec.MaxInputChars;
    public const int MinBackupPassphraseChars = 12;
}
