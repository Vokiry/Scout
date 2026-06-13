using Android.App;
using Android.Content;

namespace Soulseek.Maui.Services;

public class NotificationService
{
    private int _id;

    public void ShowPmNotification(string from, string message)
    {
        var intent = Platform.CurrentActivity?.Intent;
        var pendingIntentFlags = PendingIntentFlags.UpdateCurrent | PendingIntentFlags.Immutable;
        var pendingIntent = PendingIntent.GetActivity(
            Platform.CurrentActivity, 0, intent, pendingIntentFlags);

        var notification = new Notification.Builder(Platform.CurrentActivity!, "scout_pm")
            .SetContentTitle(from)
            .SetContentText(message)
            .SetSmallIcon(global::Android.Resource.Drawable.IcDialogEmail)
            .SetAutoCancel(true)
            .SetContentIntent(pendingIntent)
            .Build();

        var mgr = Platform.CurrentActivity?.GetSystemService(Context.NotificationService)
            as NotificationManager;
        mgr?.Notify(++_id, notification);
    }

    public void ShowDownloadCompleteNotification(string filename)
    {
        var intent = Platform.CurrentActivity?.Intent;
        var pendingIntentFlags = PendingIntentFlags.UpdateCurrent | PendingIntentFlags.Immutable;
        var pendingIntent = PendingIntent.GetActivity(
            Platform.CurrentActivity, 0, intent, pendingIntentFlags);

        var notification = new Notification.Builder(Platform.CurrentActivity!, "scout_downloads")
            .SetContentTitle("Download Complete")
            .SetContentText(filename)
            .SetSmallIcon(global::Android.Resource.Drawable.IcDialogInfo)
            .SetAutoCancel(true)
            .SetContentIntent(pendingIntent)
            .Build();

        var mgr = Platform.CurrentActivity?.GetSystemService(Context.NotificationService)
            as NotificationManager;
        mgr?.Notify(++_id, notification);
    }
}
