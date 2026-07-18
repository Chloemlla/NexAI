using System.Runtime.InteropServices;

namespace NexAI.WinUI3;

internal static partial class NativeMethods
{
    public const int SwRestore = 9;
    public const uint MbOk = 0x00000000;
    public const uint MbIconError = 0x00000010;

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool ShowWindow(nint hWnd, int nCmdShow);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool SetForegroundWindow(nint hWnd);

    [LibraryImport("user32.dll", StringMarshalling = StringMarshalling.Utf16, EntryPoint = "MessageBoxW")]
    public static partial int MessageBox(nint hWnd, string text, string caption, uint type);
}
