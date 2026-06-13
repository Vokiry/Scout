using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Soulseek.Protocol;
using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Services;

namespace Soulseek.Maui.ViewModels;

public partial class SearchResultItem : ObservableObject
{
    [ObservableProperty] private string _username = string.Empty;
    [ObservableProperty] private string _filename = string.Empty;
    [ObservableProperty] private int _size;
    [ObservableProperty] private int _bitrate;
    [ObservableProperty] private int _duration;
    [ObservableProperty] private string _extension = string.Empty;
    [ObservableProperty] private int _freeSlots;
    [ObservableProperty] private int _uploadSpeed;
    [ObservableProperty] private int _queueLength;
    [ObservableProperty] private int _fileCode;
}

public partial class SearchUserGroup : ObservableCollection<SearchResultItem>
{
    public string Username { get; }
    public string FileCount => $"{Count} file{(Count == 1 ? "" : "s")}";
    public SearchUserGroup(string username, IEnumerable<SearchResultItem> items) : base(items)
    {
        Username = username;
    }
}

public partial class SearchViewModel : ObservableObject
{
    private readonly Services.SoulseekClientService _client;
    private int _totalResults;

    [ObservableProperty] private string _query = string.Empty;
    [ObservableProperty] private bool _isSearching;
    [ObservableProperty] private string _statusText = "";
    [ObservableProperty] private string _filterType = "All";
    [ObservableProperty] private int _minBitrate;

    public ObservableCollection<SearchUserGroup> Results { get; } = new();
    public string[] FilterTypes => ["All", "Audio", "Video", "Image", "Document", "Archive"];

    private IDisposable? _sub;

    public SearchViewModel(Services.SoulseekClientService client)
    {
        _client = client;
    }

    public void OnAppearing()
    {
        _sub ??= _client.Client.SearchResults.Subscribe(OnResult);
    }

    public void OnDisappearing() { }

    private void OnResult(SearchResult result)
    {
        MainThread.BeginInvokeOnMainThread(() =>
        {
            _totalResults += result.Files.Count;
            StatusText = $"{_totalResults} results";

            var group = Results.FirstOrDefault(g => g.Username == result.Username);
            var items = result.Files
                .Where(f => MatchesFilter(f))
                .Select(f => new SearchResultItem
                {
                    Username = result.Username,
                    Filename = f.Filename,
                    Size = f.Size,
                    Bitrate = f.Bitrate,
                    Duration = f.Duration,
                    Extension = f.Extension,
                    FileCode = f.Code,
                    FreeSlots = result.FreeUploadSlots,
                    UploadSpeed = result.UploadSpeed,
                    QueueLength = result.QueueLength,
                });

            if (group == null)
            {
                group = new SearchUserGroup(result.Username, items);
                Results.Add(group);
            }
            else
            {
                foreach (var item in items)
                    group.Add(item);
            }
        });
    }

    private bool MatchesFilter(SearchResultFile f) => FilterType switch
    {
        "Audio" => IsAudio(f.Extension),
        "Video" => IsVideo(f.Extension),
        "Image" => IsImage(f.Extension),
        "Document" => IsDocument(f.Extension),
        "Archive" => IsArchive(f.Extension),
        _ => true
    };

    private static bool IsAudio(string ext) => ext is "mp3" or "flac" or "wav" or "aac" or "ogg" or "wma" or "m4a";
    private static bool IsVideo(string ext) => ext is "mp4" or "mkv" or "avi" or "mov" or "wmv";
    private static bool IsImage(string ext) => ext is "jpg" or "jpeg" or "png" or "gif" or "bmp";
    private static bool IsDocument(string ext) => ext is "pdf" or "doc" or "docx" or "txt" or "epub";
    private static bool IsArchive(string ext) => ext is "zip" or "rar" or "7z" or "tar" or "gz";

    [RelayCommand]
    private void Search()
    {
        if (string.IsNullOrWhiteSpace(Query)) return;
        Results.Clear();
        _totalResults = 0;
        IsSearching = true;
        StatusText = "Searching...";
        _client.Search(Query);
    }

    [RelayCommand]
    private async Task DownloadAsync(SearchResultItem item)
    {
        if (item == null) return;
        StatusText = $"Downloading from {item.Username}...";
        var ok = await _client.DownloadFileAsync(item.Filename, item.Size, item.Username, item.FileCode);
        StatusText = ok ? "Download started" : "Download failed";
    }

    [RelayCommand]
    private async Task BrowseUserAsync(SearchResultItem item)
    {
        if (item == null) return;
        var browseVm = IPlatformApplication.Current!.Services.GetRequiredService<BrowseViewModel>();
        browseVm.SetUsername(item.Username);
        await Shell.Current.GoToAsync("//Browse");
    }

    public void SetQuery(string q)
    {
        Query = q;
        Search();
    }
}
