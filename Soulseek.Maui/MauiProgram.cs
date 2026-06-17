using Soulseek.Maui.Services;
using Soulseek.Maui.ViewModels;
using Soulseek.Maui.Views;

namespace Soulseek.Maui;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .ConfigureFonts(fonts => { });

        // Services
        builder.Services.AddSingleton<SettingsService>();
        builder.Services.AddSingleton<SoulseekClientService>();
        builder.Services.AddSingleton<NotificationService>();

        // ViewModels — Login is transient (new instance each time)
        builder.Services.AddTransient<LoginViewModel>();
        // Shell tab pages use singletons so that cross-tab navigation works
        builder.Services.AddSingleton<SearchViewModel>();
        builder.Services.AddSingleton<RoomsViewModel>();
        builder.Services.AddSingleton<PrivateMessagesViewModel>();
        builder.Services.AddSingleton<DownloadsViewModel>();
        builder.Services.AddSingleton<BrowseViewModel>();
        builder.Services.AddSingleton<WishlistViewModel>();
        builder.Services.AddSingleton<SettingsViewModel>();

        // Pages — transient so Shell creates them per ContentTemplate
        builder.Services.AddTransient<LoginPage>();
        builder.Services.AddTransient<SearchPage>();
        builder.Services.AddTransient<RoomsPage>();
        builder.Services.AddTransient<PrivateMessagesPage>();
        builder.Services.AddTransient<DownloadsPage>();
        builder.Services.AddTransient<BrowsePage>();
        builder.Services.AddTransient<WishlistPage>();
        builder.Services.AddTransient<SettingsPage>();

        return builder.Build();
    }
}
