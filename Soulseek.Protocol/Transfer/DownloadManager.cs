using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Peer;

namespace Soulseek.Protocol.Transfer;

public enum DownloadState
{
    Queued,
    Requesting,
    Downloading,
    Paused,
    Completed,
    Failed,
    Cancelled
}

public class DownloadFile
{
    public string Filename { get; }
    public int Size { get; }
    public string Username { get; }
    public int FileCode { get; }
    public string? LocalPath { get; set; }

    public DownloadState State { get; set; }
    public int DownloadedBytes { get; set; }
    public int Position { get; set; }
    public string? Error { get; set; }
    public double? Speed { get; set; }
    public string? PlaceInQueue { get; set; }
    public int RetryCount { get; set; }

    private readonly Subject<DownloadProgress> _progressSubject = new();

    public DownloadFile(string filename, int size, string username, int fileCode, string? localPath = null,
        DownloadState state = DownloadState.Queued)
    {
        Filename = filename;
        Size = size;
        Username = username;
        FileCode = fileCode;
        LocalPath = localPath ?? DefaultPath(filename);
        State = state;
    }

    public IObservable<DownloadProgress> Progress => _progressSubject;

    public void EmitProgress()
    {
        _progressSubject.OnNext(new DownloadProgress(Filename, DownloadedBytes, Size, Speed, State));
    }

    private static string DefaultPath(string filename)
    {
        var name = Path.GetFileName(filename) ?? filename;
        return Path.Combine(Path.GetTempPath(), name);
    }

    public void Dispose()
    {
        _progressSubject.Dispose();
    }
}

public record DownloadProgress(
    string Filename,
    int DownloadedBytes,
    int TotalSize,
    double? Speed,
    DownloadState State
)
{
    public double Percentage => TotalSize > 0 ? (double)DownloadedBytes / TotalSize : 0;
}

public class DownloadManager
{
    private readonly Dictionary<string, DownloadFile> _downloads = new();
    private readonly Subject<Dictionary<string, DownloadProgress>> _progressSubject = new();
    private readonly Dictionary<string, PeerConnection> _activeConnections = new();

    public int MaxConcurrent { get; }
    public int MaxRetries { get; }
    private int _activeCount;

    public DownloadManager(int maxConcurrent = 3, int maxRetries = 3)
    {
        MaxConcurrent = maxConcurrent;
        MaxRetries = maxRetries;
    }

    public IObservable<Dictionary<string, DownloadProgress>> AllProgress => _progressSubject;
    public int ActiveDownloadCount => _activeCount;
    public int QueuedDownloadCount => _downloads.Values.Count(d => d.State == DownloadState.Queued);

    public DownloadFile AddDownload(string filename, int size, string username, int fileCode, string? localPath = null)
    {
        var download = new DownloadFile(filename, size, username, fileCode, localPath);
        _downloads[$"{username}:{filename}"] = download;
        EmitProgress();
        ProcessQueue();
        return download;
    }

    public async Task StartDownload(DownloadFile download, PeerConnection connection)
    {
        if (download.State != DownloadState.Queued && download.State != DownloadState.Failed) return;

        _activeCount++;
        download.State = DownloadState.Requesting;
        _activeConnections[$"{download.Username}:{download.Filename}"] = connection;
        EmitProgress();

        try
        {
            var request = new TransferRequest(Direction.Download, download.FileCode, download.Filename, download.Size);
            connection.SendMessage(new SoulseekMessage(request.Code, request.Serialize().ToBytes()));

            download.State = DownloadState.Downloading;
            EmitProgress();

            await ReceiveFile(download, connection);
        }
        catch (Exception e)
        {
            download.State = DownloadState.Failed;
            download.Error = e.Message;
            if (download.RetryCount < MaxRetries)
            {
                download.RetryCount++;
                download.State = DownloadState.Queued;
            }
            EmitProgress();
        }
        finally
        {
            _activeCount--;
            _activeConnections.Remove($"{download.Username}:{download.Filename}");
            ProcessQueue();
        }
    }

    private async Task ReceiveFile(DownloadFile download, PeerConnection connection)
    {
        var filePath = download.LocalPath ?? Path.Combine(Path.GetTempPath(), Path.GetFileName(download.Filename));
        await using var fileStream = new FileStream(filePath, FileMode.Create, FileAccess.Write);
        int lastBytes = 0;
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        var responseReceived = false;

        var tcs = new TaskCompletionSource();

        using var sub = connection.Messages.Subscribe(message =>
        {
            if (message.Code != PeerCode.TransferResponse) return;

            try
            {
                if (!responseReceived)
                {
                    responseReceived = true;
                    if (message.Payload.Length >= 4)
                    {
                        var response = BitConverter.ToInt32(message.Payload, 0);
                        if (response != 0)
                        {
                            download.State = DownloadState.Failed;
                            download.Error = $"Transfer denied (code: {response})";
                            download.EmitProgress();
                            EmitProgress();
                            tcs.TrySetResult();
                            return;
                        }
                    }
                    return;
                }

                fileStream.Write(message.Payload, 0, message.Payload.Length);
                download.DownloadedBytes += message.Payload.Length;
                download.Position += message.Payload.Length;

                if (stopwatch.ElapsedMilliseconds >= 500)
                {
                    var elapsed = stopwatch.ElapsedMilliseconds / 1000.0;
                    download.Speed = (download.DownloadedBytes - lastBytes) / elapsed;
                    lastBytes = download.DownloadedBytes;
                    stopwatch.Restart();
                }

                EmitProgress();
                download.EmitProgress();

                if (download.DownloadedBytes >= download.Size)
                {
                    download.State = DownloadState.Completed;
                    EmitProgress();
                    download.EmitProgress();
                    tcs.TrySetResult();
                }
            }
            catch (Exception ex)
            {
                if (!tcs.Task.IsCompleted)
                {
                    download.State = DownloadState.Failed;
                    download.Error = ex.Message;
                    tcs.TrySetResult();
                }
            }
        });

        await tcs.Task;
    }

    public void PauseDownload(DownloadFile download)
    {
        if (download.State == DownloadState.Downloading)
        {
            download.State = DownloadState.Paused;
            EmitProgress();
            download.EmitProgress();
        }
    }

    public void ResumeDownload(DownloadFile download)
    {
        if (download.State == DownloadState.Paused)
        {
            download.State = DownloadState.Queued;
            EmitProgress();
            ProcessQueue();
        }
    }

    public void CancelDownload(DownloadFile download)
    {
        download.State = DownloadState.Cancelled;
        EmitProgress();
        download.EmitProgress();
    }

    public void RemoveDownload(DownloadFile download)
    {
        _downloads.Remove($"{download.Username}:{download.Filename}");
        _activeConnections.Remove($"{download.Username}:{download.Filename}");
        download.Dispose();
        EmitProgress();
    }

    public void RetryDownload(DownloadFile download)
    {
        if (download.State == DownloadState.Failed)
        {
            download.RetryCount = 0;
            download.State = DownloadState.Queued;
            EmitProgress();
            ProcessQueue();
        }
    }

    private void ProcessQueue()
    {
        if (_activeCount >= MaxConcurrent) return;

        var queued = _downloads.Values.Where(d => d.State == DownloadState.Queued).ToList();

        foreach (var download in queued)
        {
            if (_activeCount >= MaxConcurrent) break;
            var key = $"{download.Username}:{download.Filename}";
            if (_activeConnections.TryGetValue(key, out var conn))
            {
                _activeCount++;
                download.State = DownloadState.Requesting;
                EmitProgress();
                _ = StartQueuedDownload(download, conn);
            }
        }
    }

    private async Task StartQueuedDownload(DownloadFile download, PeerConnection connection)
    {
        try
        {
            await StartDownload(download, connection);
        }
        catch (Exception e)
        {
            download.State = DownloadState.Failed;
            download.Error = e.Message;
            EmitProgress();
        }
    }

    private void EmitProgress()
    {
        var progressMap = new Dictionary<string, DownloadProgress>();
        foreach (var entry in _downloads)
        {
            var d = entry.Value;
            progressMap[entry.Key] = new DownloadProgress(d.Filename, d.DownloadedBytes, d.Size, d.Speed, d.State);
        }
        _progressSubject.OnNext(progressMap);
    }

    public void Dispose()
    {
        _progressSubject.Dispose();
        foreach (var d in _downloads.Values)
            d.Dispose();
        _downloads.Clear();
        _activeConnections.Clear();
    }
}