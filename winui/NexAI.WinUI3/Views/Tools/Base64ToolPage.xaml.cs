using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using NexAI.Core.Tools;
using Windows.ApplicationModel.DataTransfer;
using NexAI.WinUI3;

namespace NexAI.WinUI3.Views.Tools;

public sealed partial class Base64ToolPage : Page
{
    public Base64ToolPage()
    {
        InitializeComponent();
    }

    private void BackButton_Click(object sender, RoutedEventArgs e)
    {
        if (Frame?.CanGoBack == true) Frame.GoBack();
    }

    private void EncodeInputBox_TextChanged(object sender, TextChangedEventArgs e) => Encode();
    private void DecodeInputBox_TextChanged(object sender, TextChangedEventArgs e) => Decode();
    private void EncodeOptions_Changed(object sender, RoutedEventArgs e) => Encode();
    private void DecodeOptions_Changed(object sender, RoutedEventArgs e) => Decode();

    private void Encode()
    {
        try
        {
            EncodeErrorText.Text = string.Empty;
            EncodeOutputBox.Text = Base64Codec.Encode(EncodeInputBox.Text ?? string.Empty, EncodeUrlSafeToggle.IsOn);
        }
        catch (Exception ex)
        {
            EncodeOutputBox.Text = string.Empty;
            EncodeErrorText.Text = $"Encode failed: {ex.Message}";
        }
    }

    private void Decode()
    {
        try
        {
            DecodeErrorText.Text = string.Empty;
            DecodeOutputBox.Text = Base64Codec.Decode(DecodeInputBox.Text ?? string.Empty, DecodeUrlSafeToggle.IsOn);
        }
        catch (Exception ex)
        {
            DecodeOutputBox.Text = string.Empty;
            DecodeErrorText.Text = $"Decode failed: {ex.Message}";
        }
    }

    private async void PasteEncode_Click(object sender, RoutedEventArgs e)
    {
        var text = await ReadClipboardAsync();
        if (string.IsNullOrEmpty(text)) return;
        EncodeInputBox.Text = text;
        Encode();
    }

    private async void PasteDecode_Click(object sender, RoutedEventArgs e)
    {
        var text = await ReadClipboardAsync();
        if (string.IsNullOrEmpty(text)) return;
        DecodeInputBox.Text = text;
        Decode();
    }

    private void ClearAll_Click(object sender, RoutedEventArgs e)
    {
        EncodeInputBox.Text = string.Empty;
        EncodeOutputBox.Text = string.Empty;
        DecodeInputBox.Text = string.Empty;
        DecodeOutputBox.Text = string.Empty;
        EncodeErrorText.Text = string.Empty;
        DecodeErrorText.Text = string.Empty;
    }

    private void CopyEncode_Click(object sender, RoutedEventArgs e) => Copy(EncodeOutputBox.Text);
    private void CopyDecode_Click(object sender, RoutedEventArgs e) => Copy(DecodeOutputBox.Text);

    private static void Copy(string? text)
    {
        if (string.IsNullOrEmpty(text)) return;
        var data = new DataPackage();
        data.SetText(text);
        Clipboard.SetContent(data);
    }

    private static async Task<string?> ReadClipboardAsync()
    {
        var view = Clipboard.GetContent();
        if (!view.Contains(StandardDataFormats.Text)) return null;
        return await view.GetTextAsync();
    }
}
