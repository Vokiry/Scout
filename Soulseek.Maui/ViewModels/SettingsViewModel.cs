using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace Soulseek.Maui.ViewModels;

public partial class SettingsViewModel : ObservableObject
{
    private readonly Services.SoulseekClientService _client;
    private readonly Services.SettingsService _settings;

    [ObservableProperty] private string _serverHost = "server.slsknet.org";
    [ObservableProperty] private string _serverPort = "2244";
    [ObservableProperty] private bool _savePassword;
    [ObservableProperty] private bool _notificationsEnabled;
    [ObservableProperty] private string _versionInfo = "Scout v1.0.0";
    [ObservableProperty] private string _downloadPath = "";

    public SettingsViewModel(Services.SoulseekClientService client, Services.SettingsService settings)
    {
        _client = client;
        _settings = settings;
        Load();
    }

    private void Load()
    {
        ServerHost = _settings.ServerHost;
        ServerPort = _settings.ServerPort.ToString();
        SavePassword = _settings.SavePassword;
        NotificationsEnabled = _settings.NotificationsEnabled;
        DownloadPath = string.IsNullOrEmpty(_settings.DownloadPath)
            ? Services.SoulseekClientService.GetDownloadDirectory()
            : _settings.DownloadPath;
    }

    [RelayCommand]
    private void SaveServer()
    {
        if (int.TryParse(ServerPort, out var port))
        {
            _settings.ServerPort = port;
            _settings.ServerHost = ServerHost;
            _client.Client.SetServer(ServerHost, port);
        }
    }

    [RelayCommand]
    private void ToggleSavePassword()
    {
        _settings.SavePassword = SavePassword;
        if (!SavePassword)
            _settings.Password = "";
    }

    [RelayCommand]
    private void ToggleNotifications()
    {
        _settings.NotificationsEnabled = NotificationsEnabled;
    }

    [RelayCommand]
    private void ResetSettings()
    {
        Preferences.Clear();
        SecureStorage.RemoveAll();
        Load();
    }
}
