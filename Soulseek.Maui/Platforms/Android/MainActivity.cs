using Android.App;
using Android.Content.PM;
using Android.OS;

namespace Soulseek.Maui;

[Activity(
    Theme = "@style/Maui.SplashTheme",
    MainLauncher = true,
    ConfigurationChanges = ConfigChanges.ScreenSize | ConfigChanges.Orientation |
                           ConfigChanges.UiMode | ConfigChanges.ScreenLayout |
                           ConfigChanges.SmallestScreenSize | ConfigChanges.Density)]
public class MainActivity : MauiAppCompatActivity
{
    protected override void OnCreate(Bundle? savedInstanceState)
    {
        base.OnCreate(savedInstanceState);

        if (Build.VERSION.SdkInt >= BuildVersionCodes.O)
        {
            var pmChannel = new NotificationChannel(
                "scout_pm", "Private Messages", NotificationImportance.High)
            {
                Description = "New private messages"
            };
            var dlChannel = new NotificationChannel(
                "scout_downloads", "Downloads", NotificationImportance.Default)
            {
                Description = "Download complete notifications"
            };
            var sysChannel = new NotificationChannel(
                "scout_system", "System", NotificationImportance.Low)
            {
                Description = "Connection status"
            };

            var mgr = GetSystemService(NotificationService) as NotificationManager;
            mgr?.CreateNotificationChannel(pmChannel);
            mgr?.CreateNotificationChannel(dlChannel);
            mgr?.CreateNotificationChannel(sysChannel);
        }
    }
}
