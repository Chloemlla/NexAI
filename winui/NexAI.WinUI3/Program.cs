#if DISABLE_XAML_GENERATED_MAIN
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using NexAI.Core;
using WinRT;

namespace NexAI.WinUI3;

public static partial class Program
{
    [LibraryImport("Microsoft.ui.xaml.dll")]
    private static partial void XamlCheckProcessRequirements();

    [STAThread]
    private static void Main(string[] args)
    {
        // Earliest possible breadcrumb: proves the process entered managed main.
        // If this never appears, the package/runtime failed before App bootstrap.
        TryLogBootstrap("Main enter");

        try
        {
            XamlCheckProcessRequirements();
            TryLogBootstrap("XamlCheckProcessRequirements ok");

            ComWrappersSupport.InitializeComWrappers();
            TryLogBootstrap("ComWrappers initialized");

            Application.Start(p =>
            {
                try
                {
                    TryLogBootstrap("Application.Start callback enter");
                    var context = new DispatcherQueueSynchronizationContext(
                        DispatcherQueue.GetForCurrentThread());
                    SynchronizationContext.SetSynchronizationContext(context);
                    // Do not assign into the callback parameter (named discard would
                    // still be typed as ApplicationInitializationCallbackParams).
                    _ = new App();
                    TryLogBootstrap("App constructed");
                }
                catch (Exception ex)
                {
                    TryLogBootstrap("Application.Start callback fatal: " + ex);
                    throw;
                }
            });
            TryLogBootstrap("Application.Start returned");
        }
        catch (Exception ex)
        {
            TryLogBootstrap("Main fatal: " + ex);
            throw;
        }
    }

    private static void TryLogBootstrap(string message)
    {
        try
        {
            AppPaths.EnsureRoot();
            var line = DateTimeOffset.Now.ToString("O") + " [bootstrap] " + message + Environment.NewLine;
            File.AppendAllText(Path.Combine(AppPaths.RootDirectory, "startup.log"), line, Encoding.UTF8);
            Debug.WriteLine("[NexAI][bootstrap] " + message);
        }
        catch
        {
            // Never let bootstrap logging crash the process.
        }
    }
}
#endif
