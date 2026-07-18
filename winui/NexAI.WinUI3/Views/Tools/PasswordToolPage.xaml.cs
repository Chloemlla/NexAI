using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Navigation;
using NexAI.Core.Tools;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage.Pickers;
using WinRT.Interop;
using NexAI.WinUI3;

namespace NexAI.WinUI3.Views.Tools;

public sealed partial class PasswordToolPage : Page
{
    private readonly IPasswordVaultStore _vault;
    private readonly List<string> _batch = [];

    public PasswordToolPage()
    {
        InitializeComponent();
        _vault = App.Current.Services.GetRequiredService<IPasswordVaultStore>();
        GenerateCurrent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        _vault.Changed += OnVaultChanged;
        RefreshSaved();
    }

    protected override void OnNavigatedFrom(NavigationEventArgs e)
    {
        _vault.Changed -= OnVaultChanged;
        base.OnNavigatedFrom(e);
    }

    private void OnVaultChanged(object? sender, EventArgs e) => DispatcherQueue.TryEnqueue(RefreshSaved);

    private void RefreshSaved()
    {
        var items = _vault.Passwords;
        SavedList.ItemsSource = items;
        SavedCountText.Text = $"{items.Count} saved password(s)";
        SubtitleText.Text = $"Generate random / memorable / PIN passwords. Vault: {items.Count} item(s).";
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (Frame?.CanGoBack == true) Frame.GoBack();
    }

    private void TypeBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (RandomPanel is null || MemorablePanel is null || PinPanel is null) return;
        var type = ReadType();
        RandomPanel.Visibility = type == PasswordGeneratorType.Random ? Visibility.Visible : Visibility.Collapsed;
        MemorablePanel.Visibility = type == PasswordGeneratorType.Memorable ? Visibility.Visible : Visibility.Collapsed;
        PinPanel.Visibility = type == PasswordGeneratorType.Pin ? Visibility.Visible : Visibility.Collapsed;
        GenerateCurrent();
    }

    private void Options_Changed(object sender, RoutedEventArgs e) => GenerateCurrent();
    private void Options_Changed(object sender, RangeBaseValueChangedEventArgs e) => GenerateCurrent();

    private void Regenerate_Click(object sender, RoutedEventArgs e) => GenerateCurrent();

    private void GenerateCurrent()
    {
        if (GeneratedBox is null) return;
        var password = PasswordGenerator.Generate(BuildOptions());
        GeneratedBox.Text = password;
        var strength = PasswordGenerator.CalculateStrength(password);
        StrengthBar.Value = strength;
        StrengthText.Text = $"Strength: {PasswordGenerator.StrengthLabel(strength)} ({strength})";
    }

    private PasswordGeneratorOptions BuildOptions()
    {
        return new PasswordGeneratorOptions
        {
            Type = ReadType(),
            Length = (int)Math.Round(LengthSlider?.Value ?? 16),
            IncludeUppercase = UpperToggle?.IsOn ?? true,
            IncludeLowercase = LowerToggle?.IsOn ?? true,
            IncludeNumbers = NumberToggle?.IsOn ?? true,
            IncludeSymbols = SymbolToggle?.IsOn ?? true,
            WordCount = (int)Math.Round(WordCountSlider?.Value ?? 4),
            CapitalizeWords = CapitalizeToggle?.IsOn ?? true,
            AddNumbers = AddNumbersToggle?.IsOn ?? true,
            PinLength = (int)Math.Round(PinLengthSlider?.Value ?? 6),
        };
    }

    private PasswordGeneratorType ReadType()
    {
        if (TypeBox?.SelectedItem is ComboBoxItem item &&
            Enum.TryParse<PasswordGeneratorType>(item.Tag?.ToString(), true, out var type))
        {
            return type;
        }

        return PasswordGeneratorType.Random;
    }

    private void CopyCurrent_Click(object sender, RoutedEventArgs e) => CopyText(GeneratedBox.Text);

    private async void SaveCurrent_Click(object sender, RoutedEventArgs e)
    {
        var password = GeneratedBox.Text ?? string.Empty;
        if (string.IsNullOrWhiteSpace(password)) return;
        await SavePasswordAsync(password);
    }

    private void GenerateBatch_Click(object sender, RoutedEventArgs e)
    {
        var count = (int)Math.Round(BatchCountSlider.Value);
        _batch.Clear();
        _batch.AddRange(PasswordGenerator.GenerateBatch(BuildOptions(), count));
        BatchList.ItemsSource = _batch.ToList();
    }

    private async void ExportBatch_Click(object sender, RoutedEventArgs e)
    {
        if (_batch.Count == 0)
        {
            await ShowMessageAsync("No batch passwords to export.");
            return;
        }

        if (!await ConfirmSensitiveExportAsync("Export batch passwords as plaintext CSV?"))
        {
            return;
        }

        var sb = new System.Text.StringBuilder();
        sb.AppendLine("Index,Password,Strength");
        for (var i = 0; i < _batch.Count; i++)
        {
            var strength = PasswordGenerator.CalculateStrength(_batch[i]);
            sb.Append(i + 1).Append(",\"").Append(_batch[i].Replace("\"", "\"\""))
                .Append("\",\"").Append(PasswordGenerator.StrengthLabel(strength)).AppendLine("\"");
        }

        await SaveTextFileAsync(
            $"passwords_{DateTime.Now:yyyyMMdd_HHmmss}.csv",
            sb.ToString());
    }

    private void CopyBatchItem_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string password })
        {
            CopyText(password);
        }
    }

    private async void SaveBatchItem_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string password })
        {
            await SavePasswordAsync(password);
        }
    }

    private void CopySaved_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: SavedPassword item })
        {
            CopyText(item.Password);
        }
    }

    private async void DeleteSaved_Click(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: SavedPassword item })
        {
            await _vault.DeleteAsync(item.Id);
        }
    }

    private async void ExportSaved_Click(object sender, RoutedEventArgs e)
    {
        if (!await ConfirmSensitiveExportAsync(
                "Export saved passwords as plaintext CSV? Prefer encrypted backup for safer transfer."))
        {
            return;
        }

        await SaveTextFileAsync(
            $"saved_passwords_{DateTime.Now:yyyyMMdd_HHmmss}.csv",
            _vault.ExportCsv());
    }

    private async void Backup_Click(object sender, RoutedEventArgs e)
    {
        var passphrase = await PromptPassphraseAsync("Create encrypted backup", confirm: true);
        if (passphrase is null) return;
        try
        {
            var backup = await _vault.CreateBackupAsync(passphrase);
            await SaveTextFileAsync($"password_backup_{DateTime.Now:yyyyMMdd_HHmmss}.json", backup);
        }
        catch (Exception ex)
        {
            await ShowMessageAsync(ex.Message);
        }
    }

    private async void Restore_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var picker = new FileOpenPicker();
            picker.FileTypeFilter.Add(".json");
            picker.FileTypeFilter.Add("*");
            InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(App.Current.MainWindow));
            var file = await picker.PickSingleFileAsync();
            if (file is null) return;

            var json = await File.ReadAllTextAsync(file.Path);
            if (PasswordBackupCrypto.IsLegacyPlaintextBackup(json))
            {
                if (!await ConfirmSensitiveExportAsync(
                        "This backup is legacy plaintext (v1). Importing will replace the vault with unprotected data. Continue?"))
                {
                    return;
                }

                var legacy = PasswordBackupCrypto.RestoreLegacyPlaintextBackup(json);
                await _vault.ReplaceAllAsync(legacy);
                await ShowMessageAsync("Legacy plaintext backup restored.");
                return;
            }

            string? passphrase = null;
            if (json.Contains(PasswordBackupCrypto.EncryptedBackupFormat, StringComparison.Ordinal) ||
                json.Contains(PasswordBackupCrypto.EncryptedBackupVersion, StringComparison.Ordinal))
            {
                passphrase = await PromptPassphraseAsync("Restore encrypted backup", confirm: false);
                if (passphrase is null) return;
            }

            await _vault.RestoreBackupAsync(json, passphrase);
            await ShowMessageAsync("Backup restored.");
        }
        catch (Exception ex)
        {
            await ShowMessageAsync(ex.Message);
        }
    }

    private async void ClearVault_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new ContentDialog
        {
            Title = "Clear password vault",
            Content = "Delete all saved passwords from this device?",
            PrimaryButtonText = "Clear",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot,
        };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;
        await _vault.ClearAsync();
    }

    private async Task SavePasswordAsync(string password)
    {
        var categoryBox = new TextBox { Header = "Category / usage", PlaceholderText = "e.g. Email, Bank" };
        var noteBox = new TextBox { Header = "Note", PlaceholderText = "Optional note", Margin = new Thickness(0, 12, 0, 0) };
        var panel = new StackPanel();
        panel.Children.Add(categoryBox);
        panel.Children.Add(noteBox);

        var dialog = new ContentDialog
        {
            Title = "Save password",
            Content = panel,
            PrimaryButtonText = "Save",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;

        await _vault.AddAsync(new SavedPassword
        {
            Password = password,
            Category = string.IsNullOrWhiteSpace(categoryBox.Text) ? "Uncategorized" : categoryBox.Text.Trim(),
            Note = noteBox.Text?.Trim() ?? string.Empty,
            Strength = PasswordGenerator.CalculateStrength(password),
            CreatedAt = DateTime.UtcNow,
        });
    }

    private async Task<string?> PromptPassphraseAsync(string title, bool confirm)
    {
        var passBox = new PasswordBox { Header = $"Passphrase (min {ToolInputLimits.MinBackupPassphraseChars} chars)" };
        var confirmBox = new PasswordBox { Header = "Confirm passphrase", Margin = new Thickness(0, 12, 0, 0) };
        var panel = new StackPanel();
        panel.Children.Add(passBox);
        if (confirm) panel.Children.Add(confirmBox);

        var dialog = new ContentDialog
        {
            Title = title,
            Content = panel,
            PrimaryButtonText = "Continue",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return null;

        var passphrase = passBox.Password?.Trim() ?? string.Empty;
        // Creating backups requires the stronger policy; restore keeps a lower floor so older
        // 8-character backups remain recoverable.
        var minChars = confirm ? ToolInputLimits.MinBackupPassphraseChars : 8;
        if (passphrase.Length < minChars)
        {
            await ShowMessageAsync($"Passphrase must be at least {minChars} characters.");
            return null;
        }

        if (confirm && !string.Equals(passphrase, confirmBox.Password?.Trim(), StringComparison.Ordinal))
        {
            await ShowMessageAsync("Passphrases do not match.");
            return null;
        }

        return passphrase;
    }


    private async Task<bool> ConfirmSensitiveExportAsync(string message)
    {
        var dialog = new ContentDialog
        {
            Title = "Security confirmation",
            Content = message,
            PrimaryButtonText = "Continue",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = XamlRoot,
        };
        return await dialog.ShowAsync() == ContentDialogResult.Primary;
    }

    private async Task SaveTextFileAsync(string fileName, string content)
    {
        var picker = new FileSavePicker
        {
            SuggestedFileName = fileName,
        };
        picker.FileTypeChoices.Add("File", new List<string> { Path.GetExtension(fileName) is { Length: > 0 } ext ? ext : ".txt" });
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(App.Current.MainWindow));
        var file = await picker.PickSaveFileAsync();
        if (file is null) return;
        await File.WriteAllTextAsync(file.Path, content);
    }

    private async Task ShowMessageAsync(string message)
    {
        var dialog = new ContentDialog
        {
            Title = "Password tool",
            Content = message,
            CloseButtonText = "OK",
            XamlRoot = XamlRoot,
        };
        await dialog.ShowAsync();
    }

    private static void CopyText(string? text)
    {
        if (string.IsNullOrEmpty(text)) return;
        var data = new DataPackage();
        data.SetText(text);
        Clipboard.SetContent(data);
    }
}
