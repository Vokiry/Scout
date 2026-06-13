using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Soulseek.Protocol.Connection;

namespace Soulseek.Maui.ViewModels;

public partial class LoginViewModel : ObservableObject
{
    private readonly Services.SoulseekClientService _client;
    private readonly Services.SettingsService _settings;

    [ObservableProperty] private string _username = string.Empty;
    [ObservableProperty] private string _password = string.Empty;
    [ObservableProperty] private bool _isConnecting;
    [ObservableProperty] private string _statusText = "";
    [ObservableProperty] private bool _savePassword;
    [ObservableProperty] private string _serverHost = "server.slsknet.org";
    [ObservableProperty] private string _serverPort = "2244";

    public LoginViewModel(Services.SoulseekClientService client, Services.SettingsService settings)
    {
        _client = client;
        _settings = settings;
        LoadSaved();
    }

    private void LoadSaved()
    {
        Username = _settings.Username;
        SavePassword = _settings.SavePassword;
        ServerHost = _settings.ServerHost;
        ServerPort = _settings.ServerPort.ToString();
        if (SavePassword)
            Password = _settings.Password;
    }

    [RelayCommand]
    private async Task ConnectAsync()
    {
        if (string.IsNullOrWhiteSpace(Username))
        {
            StatusText = "Enter your username";
            return;
        }
        if (string.IsNullOrWhiteSpace(Password) && !string.IsNullOrWhiteSpace(_settings.Password))
            Password = _settings.Password;
        if (string.IsNullOrWhiteSpace(Password))
        {
            StatusText = "Enter your password";
            return;
        }

        IsConnecting = true;
        StatusText = "Connecting...";

        try
        {
            _settings.Username = Username;
            _settings.SavePassword = SavePassword;
            if (SavePassword) _settings.Password = Password;
            else _settings.Password = "";

            if (int.TryParse(ServerPort, out var port))
                _settings.ServerPort = port;
            _settings.ServerHost = ServerHost;

            _client.Client.SetServer(ServerHost, port);
            await _client.ConnectAsync(Username, Password);

            if (_client.IsConnected)
            {
                StatusText = "Connected!";
                _settings.AutoConnect = true;
                if (Application.Current != null)
                    Application.Current.MainPage = new AppShell();
            }
            else
            {
                StatusText = "Authentication failed — check your credentials";
            }
        }
        catch (Exception ex)
        {
            StatusText = $"Connection failed: {ex.Message}";
        }
        finally
        {
            IsConnecting = false;
        }
    }
}
