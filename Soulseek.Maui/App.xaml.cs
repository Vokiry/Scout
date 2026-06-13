using Soulseek.Maui.Services;
using Soulseek.Maui.ViewModels;
using Soulseek.Maui.Views;

namespace Soulseek.Maui;

public partial class App : Application
{
    public App()
    {
        InitializeComponent();
    }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        var services = IPlatformApplication.Current!.Services;
        var settings = services.GetRequiredService<SettingsService>();
        var client = services.GetRequiredService<SoulseekClientService>();

        var vm = new LoginViewModel(client, settings);
        var page = new LoginPage(vm);

        if (settings.AutoConnect && settings.SavePassword && !string.IsNullOrEmpty(settings.Password))
        {
            _ = Task.Run(async () =>
            {
                await Task.Delay(500);
                MainThread.BeginInvokeOnMainThread(() => vm.ConnectCommand.Execute(null));
            });
        }

        return new Window(page);
    }
}
