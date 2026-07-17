#if DISABLE_XAML_GENERATED_MAIN
using System.Runtime.InteropServices;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using WinRT;

namespace NexAI.WinUI3;

public static partial class Program
{
    [LibraryImport("Microsoft.ui.xaml.dll")]
    private static partial void XamlCheckProcessRequirements();

    [STAThread]
    private static void Main(string[] args)
    {
        XamlCheckProcessRequirements();
        ComWrappersSupport.InitializeComWrappers();
        Application.Start(p =>
        {
            var context = new DispatcherQueueSynchronizationContext(
                DispatcherQueue.GetForCurrentThread());
            SynchronizationContext.SetSynchronizationContext(context);
            // Do not assign into the callback parameter (named discard would
            // still be typed as ApplicationInitializationCallbackParams).
            new App();
        });
    }
}
#endif
