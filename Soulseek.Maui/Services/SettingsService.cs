namespace Soulseek.Maui.Services;

public class SettingsService
{
    public string Username
    {
        get => Preferences.Get("username", "");
        set => Preferences.Set("username", value);
    }
    public string Password
    {
        get => SecureStorage.GetAsync("password").Result ?? "";
        set
        {
            if (string.IsNullOrEmpty(value))
                SecureStorage.Remove("password");
            else
                SecureStorage.SetAsync("password", value).Wait();
        }
    }
    public bool SavePassword
    {
        get => Preferences.Get("save_password", false);
        set => Preferences.Set("save_password", value);
    }
    public bool AutoConnect
    {
        get => Preferences.Get("auto_connect", false);
        set => Preferences.Set("auto_connect", value);
    }
    public string ServerHost
    {
        get => Preferences.Get("server_host", "server.slsknet.org");
        set => Preferences.Set("server_host", value);
    }
    public int ServerPort
    {
        get => Preferences.Get("server_port", 2244);
        set => Preferences.Set("server_port", value);
    }
    public string DownloadPath
    {
        get => Preferences.Get("download_path", "");
        set => Preferences.Set("download_path", value);
    }
    public bool NotificationsEnabled
    {
        get => Preferences.Get("notifications", true);
        set => Preferences.Set("notifications", value);
    }
}
