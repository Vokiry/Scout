using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Soulseek.Protocol.Messages;

namespace Soulseek.Maui.ViewModels;

public partial class BrowseFileItem : ObservableObject
{
    [ObservableProperty] private string _filename = string.Empty;
    [ObservableProperty] private long _size;
    [ObservableProperty] private string _extension = string.Empty;
    [ObservableProperty] private int _bitrate;
    [ObservableProperty] private int _duration;
    [ObservableProperty] private string _folderPath = string.Empty;
    [ObservableProperty] private int _fileCode;
    [ObservableProperty] private string _username = string.Empty;
}

public partial class BrowseFolderGroup : ObservableCollection<BrowseFileItem>
{
    public string Path { get; }
    public string FileCount => $"{Count} file{(Count == 1 ? "" : "s")}";
    public BrowseFolderGroup(string path, IEnumerable<BrowseFileItem> items) : base(items) { Path = path; }
}

public partial class BrowseViewModel : ObservableObject
{
    private readonly Services.SoulseekClientService _client;
    private string _queuedUsername = "";

    [ObservableProperty] private string _username = string.Empty;
    [ObservableProperty] private bool _isBrowsing;
    [ObservableProperty] private string _statusText = "";
    [ObservableProperty] private BrowseFolderGroup? _selectedFolder;

    public ObservableCollection<BrowseFolderGroup> Folders { get; } = new();

    public BrowseViewModel(Services.SoulseekClientService client)
    {
        _client = client;
    }

    public void SetUsername(string u)
    {
        if (IsBrowsing) { _queuedUsername = u; return; }
        Username = u;
        BrowseCommand.Execute(null);
    }

    [RelayCommand]
    private async Task BrowseAsync()
    {
        var user = _queuedUsername ?? Username;
        _queuedUsername = "";
        if (string.IsNullOrWhiteSpace(user)) return;

        IsBrowsing = true;
        StatusText = $"Resolving {user}...";
        Folders.Clear();

        try
        {
            var result = await _client.BrowseUserAsync(user);
            if (result == null)
            {
                StatusText = "Browse failed — user may be offline";
                return;
            }
            foreach (var folder in result.Folders)
            {
                var items = folder.Files.Select(f => new BrowseFileItem
                {
                    Filename = Path.GetFileName(f.Filename),
                    Size = f.Size,
                    Extension = f.Extension,
                    Bitrate = f.Bitrate,
                    Duration = f.Duration,
                    FolderPath = folder.Path,
                    FileCode = f.Code,
                    Username = user,
                });
                Folders.Add(new BrowseFolderGroup(folder.Path, items));
            }
            var total = result.Folders.Sum(f => f.Files.Count);
            StatusText = $"{total} files in {result.Folders.Count} folders";
        }
        catch (Exception ex)
        {
            StatusText = $"Error: {ex.Message}";
        }
        finally { IsBrowsing = false; }
    }

    [RelayCommand]
    private async Task DownloadFromBrowseAsync(BrowseFileItem item)
    {
        if (item == null) return;
        StatusText = $"Downloading {item.Filename}...";
        var ok = await _client.DownloadFileAsync(
            item.FolderPath + "\\" + item.Filename,
            (int)item.Size, item.Username, item.FileCode);
        StatusText = ok ? "Download started" : "Download failed";
    }
}
