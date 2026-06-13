using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Peer;

namespace Soulseek.Protocol.Transfer;

public enum UploadState
{
    Queued,
    Uploading,
    Paused,
    Completed,
    Failed,
    Cancelled
}

public class UploadFile
{
    public string Filename { get; }
    public int Size { get; }
    public string Username { get; }
    public int FileCode { get; }
    public string LocalPath { get; }
    public UploadState State { get; set; }
    public int UploadedBytes { get; set; }
    public double? Speed { get; set; }
    public string? Error { get; set; }

    public UploadFile(string filename, int size, string username, int fileCode, string localPath,
        UploadState state = UploadState.Queued)
    {
        Filename = filename;
        Size = size;
        Username = username;
        FileCode = fileCode;
        LocalPath = localPath;
        State = state;
    }
}

public record UploadProgress(
    string Filename,
    int UploadedBytes,
    int TotalSize,
    double? Speed,
    UploadState State
)
{
    public double Percentage => TotalSize > 0 ? (double)UploadedBytes / TotalSize : 0;
}

public class UploadManager
{
    private readonly Dictionary<string, UploadFile> _uploads = new();
    private readonly Subject<Dictionary<string, UploadProgress>> _progressSubject = new();
    private int _activeCount;

    public int MaxConcurrent { get; }
    private const int MaxChunkSize = 1024 * 1024;

    public UploadManager(int maxConcurrent = 3)
    {
        MaxConcurrent = maxConcurrent;
    }

    public IObservable<Dictionary<string, UploadProgress>> AllProgress => _progressSubject;
    public int ActiveUploadCount => _activeCount;

    public void AddUpload(string filename, int size, string username, int fileCode, string localPath)
    {
        var upload = new UploadFile(filename, size, username, fileCode, localPath);
        _uploads[$"{username}:{filename}"] = upload;
        EmitProgress();
    }

    public async Task HandleTransferRequest(
        TransferRequest request,
        ITransferConnection connection,
        Func<string, int, bool>? onRequest = null)
    {
        var key = $"{connection.Username}:{request.Filename}";
        var existing = _uploads.GetValueOrDefault(key);

        if (onRequest != null && !onRequest(request.Filename, request.FileSize))
        {
            SendTransferResponse(connection, 1);
            return;
        }

        if (existing != null)
        {
            existing.State = UploadState.Uploading;
        }
        else
        {
            var upload = new UploadFile(request.Filename, request.FileSize, connection.Username,
                request.FileCode, request.Filename, UploadState.Uploading);
            _uploads[key] = upload;
        }

        SendTransferResponse(connection, 0);
        _activeCount++;
        EmitProgress();

        try
        {
            await SendFile(connection, key, request.Filename, request.FileSize);
        }
        catch (Exception e)
        {
            if (_uploads.TryGetValue(key, out var upload))
            {
                upload.State = UploadState.Failed;
                upload.Error = e.Message;
                EmitProgress();
            }
        }
        finally
        {
            _activeCount--;
        }
    }

    private async Task SendFile(ITransferConnection connection, string key, string filename, int fileSize)
    {
        if (!File.Exists(filename))
        {
            SendTransferResponse(connection, 2);
            if (_uploads.TryGetValue(key, out var upload))
            {
                upload.State = UploadState.Failed;
                upload.Error = "File not found";
                EmitProgress();
            }
            return;
        }

        var fileStream = new FileStream(filename, FileMode.Open, FileAccess.Read);
        int sent = 0;
        var stopwatch = System.Diagnostics.Stopwatch.StartNew();

        try
        {
            while (sent < fileSize)
            {
                var chunk = new byte[Math.Min(MaxChunkSize, fileSize - sent)];
                var bytesRead = await fileStream.ReadAsync(chunk, 0, chunk.Length);
                if (bytesRead == 0) break;

                if (bytesRead < chunk.Length)
                    Array.Resize(ref chunk, bytesRead);

                var msg = new SoulseekMessage(PeerCode.TransferResponse, chunk);
                connection.SendMessage(msg);

                sent += bytesRead;

                if (_uploads.TryGetValue(key, out var upload))
                {
                    upload.UploadedBytes = sent;
                    if (stopwatch.ElapsedMilliseconds >= 500)
                    {
                        upload.Speed = bytesRead / (stopwatch.ElapsedMilliseconds / 1000.0);
                        stopwatch.Restart();
                    }
                    EmitProgress();
                }
            }

            if (_uploads.TryGetValue(key, out var uploadFinal) && uploadFinal.State != UploadState.Cancelled)
            {
                uploadFinal.State = UploadState.Completed;
                EmitProgress();
            }
        }
        finally
        {
            fileStream.Close();
        }
    }

    private void SendTransferResponse(ITransferConnection connection, int responseCode)
    {
        var w = new WriteBuffer();
        w.WriteInt32(responseCode);
        connection.SendRaw(PeerCode.TransferResponse, w.ToBytes());
    }

    public void CancelUpload(UploadFile upload)
    {
        upload.State = UploadState.Cancelled;
        EmitProgress();
    }

    public void RemoveUpload(UploadFile upload)
    {
        _uploads.Remove($"{upload.Username}:{upload.Filename}");
        EmitProgress();
    }

    private void EmitProgress()
    {
        var progressMap = new Dictionary<string, UploadProgress>();
        foreach (var entry in _uploads)
        {
            var u = entry.Value;
            progressMap[entry.Key] = new UploadProgress(u.Filename, u.UploadedBytes, u.Size, u.Speed, u.State);
        }
        _progressSubject.OnNext(progressMap);
    }

    public void Dispose()
    {
        _progressSubject.Dispose();
        _uploads.Clear();
    }
}