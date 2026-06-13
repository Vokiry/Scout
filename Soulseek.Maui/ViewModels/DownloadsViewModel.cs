using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Soulseek.Maui.ViewModels;

public partial class DownloadItem : ObservableObject
{
    [ObservableProperty] private string _filename = string.Empty;
    [ObservableProperty] private int _downloadedBytes;
    [ObservableProperty] private int _totalSize;
    [ObservableProperty] private double _speed;
    [ObservableProperty] private string _state = string.Empty;
    [ObservableProperty] private string _username = string.Empty;
    [ObservableProperty] private string _localPath = string.Empty;

    public double Percentage => TotalSize > 0 ? Math.Min(1.0, (double)DownloadedBytes / TotalSize) : 0;
    public string ProgressText => $"{DownloadedBytes / 1024} / {TotalSize / 1024} KB";
    public string SpeedText => Speed > 0 ? $"{Speed / 1024:F1} KB/s" : "";
    public string StateDisplay => State switch
    {
        "Downloading" => "⬇ Downloading",
        "Completed" => "✅ Completed",
        "Failed" => "❌ Failed",
        "Queued" => "⏳ Queued",
        "Cancelled" => "✕ Cancelled",
        _ => State,
    };
    public bool IsActive => State is "Downloading" or "Queued";
    public bool IsCompleted => State == "Completed";
    public bool CanRetry => State == "Failed";
    public bool CanOpen => IsCompleted && !string.IsNullOrEmpty(LocalPath);
}

public partial class DownloadsViewModel : ObservableObject
{
    private readonly Services.SoulseekClientService _client;
    private readonly Services.NotificationService _notifications;
    private readonly Services.SettingsService _settings;

    [ObservableProperty] private string _statusText = "";
    [ObservableProperty] private bool _showActiveOnly = true;

    public ObservableCollection<DownloadItem> Items { get; } = new();

    private IDisposable? _sub;
    private readonly Dictionary<string, bool> _notified = new();

    public DownloadsViewModel(
        Services.SoulseekClientService client,
        Services.NotificationService notifications,
        Services.SettingsService settings)
    {
        _client = client;
        _notifications = notifications;
        _settings = settings;
    }

    public void OnAppearing()
    {
        _sub ??= _client.Client.DownloadProgress.Subscribe(progress =>
        {
            MainThread.BeginInvokeOnMainThread(() =>
            {
                Items.Clear();
                foreach (var (key, p) in progress)
                {
                    var parts = key.Split(':', 2);
                    var dl = new DownloadItem
                    {
                        Filename = Path.GetFileName(p.Filename),
                        TotalSize = p.TotalSize,
                        DownloadedBytes = p.DownloadedBytes,
                        Speed = p.Speed ?? 0,
                        State = p.State.ToString(),
                        Username = parts.Length > 1 ? parts[0] : "",
                        LocalPath = "",
                    };
                    if (!ShowActiveOnly || dl.IsActive)
                        Items.Add(dl);

                    if (p.State == DownloadState.Completed && !_notified.ContainsKey(key))
                    {
                        _notified[key] = true;
                        if (_settings.NotificationsEnabled)
                            _notifications.ShowDownloadCompleteNotification(Path.GetFileName(p.Filename));
                    }
                }
                StatusText = $"{Items.Count(i => i.IsActive)} active, {Items.Count(i => i.IsCompleted)} completed";
            });
        });
    }

    [RelayCommand]
    private void ToggleFilter()
    {
        ShowActiveOnly = !ShowActiveOnly;
        StatusText = ShowActiveOnly ? "Showing active only" : "Showing all";
    }

    [RelayCommand]
    private async Task OpenFileAsync(DownloadItem item)
    {
        if (!item.CanOpen || string.IsNullOrEmpty(item.LocalPath)) return;
        try
        {
            var uri = new Android.Net.Uri.Builder()
                .Scheme("content")
                .Authority(Android.App.Application.Context.PackageName!)
                .Path(item.LocalPath)
                .Build();
            await Launcher.OpenAsync(new OpenFileRequest
            {
                File = new ReadOnlyFile(item.LocalPath)
            });
        }
        catch { }
    }
}
