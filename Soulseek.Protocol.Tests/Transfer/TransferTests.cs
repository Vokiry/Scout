using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Peer;
using Soulseek.Protocol.Transfer;

namespace Soulseek.Protocol.Tests.Transfer;

public class DownloadManagerTests
{
    [Fact]
    public void AddDownload_CreatesQueuedEntry()
    {
        var mgr = new DownloadManager();
        var dl = mgr.AddDownload("file.mp3", 1000, "user1", 5);
        Assert.Equal("file.mp3", dl.Filename);
        Assert.Equal(DownloadState.Queued, dl.State);
        Assert.Equal(1, mgr.QueuedDownloadCount);
    }

    [Fact]
    public void AddDownload_WithCustomPath()
    {
        var mgr = new DownloadManager();
        var dl = mgr.AddDownload("file.mp3", 1000, "user1", 5, "/tmp/music/file.mp3");
        Assert.Equal("/tmp/music/file.mp3", dl.LocalPath);
    }

    [Fact]
    public void PauseDownload_PausesActiveDownload()
    {
        var mgr = new DownloadManager();
        var dl = mgr.AddDownload("f.mp3", 500, "u1", 1);
        dl.State = DownloadState.Downloading;
        mgr.PauseDownload(dl);
        Assert.Equal(DownloadState.Paused, dl.State);
    }

    [Fact]
    public void PauseDownload_NonDownloading_DoesNothing()
    {
        var mgr = new DownloadManager();
        var dl = mgr.AddDownload("f.mp3", 500, "u1", 1);
        dl.State = DownloadState.Queued;
        mgr.PauseDownload(dl);
        Assert.Equal(DownloadState.Queued, dl.State);
    }

    [Fact]
    public void ResumeDownload_MovesToQueued()
    {
        var mgr = new DownloadManager();
        var dl = mgr.AddDownload("f.mp3", 500, "u1", 1);
        dl.State = DownloadState.Paused;
        mgr.ResumeDownload(dl);
        Assert.Equal(DownloadState.Queued, dl.State);
    }

    [Fact]
    public void CancelDownload_SetsStateCancelled()
    {
        var mgr = new DownloadManager();
        var dl = mgr.AddDownload("f.mp3", 500, "u1", 1);
        mgr.CancelDownload(dl);
        Assert.Equal(DownloadState.Cancelled, dl.State);
    }

    [Fact]
    public void RemoveDownload_RemovesFromCollection()
    {
        var mgr = new DownloadManager();
        var dl = mgr.AddDownload("f.mp3", 500, "u1", 1);
        mgr.RemoveDownload(dl);
        Assert.Equal(0, mgr.QueuedDownloadCount);
    }

    [Fact]
    public void RetryDownload_ResetsQueuedFromFailed()
    {
        var mgr = new DownloadManager();
        var dl = mgr.AddDownload("f.mp3", 500, "u1", 1);
        dl.State = DownloadState.Failed;
        mgr.RetryDownload(dl);
        Assert.Equal(DownloadState.Queued, dl.State);
        Assert.Equal(0, dl.RetryCount);
    }

    [Fact]
    public void RetryDownload_NonFailed_DoesNothing()
    {
        var mgr = new DownloadManager();
        var dl = mgr.AddDownload("f.mp3", 500, "u1", 1);
        dl.State = DownloadState.Completed;
        mgr.RetryDownload(dl);
        Assert.Equal(DownloadState.Completed, dl.State);
    }

    [Fact]
    public void AllProgress_EmitsOnAdd()
    {
        var mgr = new DownloadManager();
        Dictionary<string, DownloadProgress>? progress = null;
        using var sub = mgr.AllProgress.Subscribe(p => progress = p);

        mgr.AddDownload("file.mp3", 1000, "user1", 5);

        Assert.NotNull(progress);
        Assert.Single(progress);
        Assert.Equal("file.mp3", progress.Values.First().Filename);
    }

    [Fact]
    public void DownloadFile_EmitProgress_UpdatesObservers()
    {
        var dl = new DownloadFile("f.mp3", 1000, "user1", 1);
        DownloadProgress? result = null;
        using var sub = dl.Progress.Subscribe(p => result = p);
        dl.EmitProgress();
        Assert.NotNull(result);
        Assert.Equal("f.mp3", result.Filename);
    }

    [Fact]
    public void DownloadProgress_Percentage_CalculatesCorrectly()
    {
        var p = new DownloadProgress("f.mp3", 250, 1000, 100.0, DownloadState.Downloading);
        Assert.Equal(0.25, p.Percentage);
    }

    [Fact]
    public void DownloadProgress_Percentage_ZeroTotal_ReturnsZero()
    {
        var p = new DownloadProgress("f.mp3", 0, 0, null, DownloadState.Queued);
        Assert.Equal(0, p.Percentage);
    }
}

public class UploadManagerTests
{
    [Fact]
    public void AddUpload_AddsToCollection()
    {
        var mgr = new UploadManager();
        mgr.AddUpload("file.mp3", 1000, "user1", 3, "/files/file.mp3");
        Assert.Equal(1, mgr.ActiveUploadCount);
    }

    [Fact]
    public void CancelUpload_SetsCancelled()
    {
        var mgr = new UploadManager();
        mgr.AddUpload("f.mp3", 100, "u1", 1, "/f.mp3");
        var upload = new UploadFile("f.mp3", 100, "u1", 1, "/f.mp3", UploadState.Uploading);
        mgr.CancelUpload(upload);
        Assert.Equal(UploadState.Cancelled, upload.State);
    }

    [Fact]
    public void RemoveUpload_RemovesFromCollection()
    {
        var mgr = new UploadManager();
        var upload = new UploadFile("f.mp3", 100, "u1", 1, "/f.mp3", UploadState.Completed);
        mgr.AddUpload("f.mp3", 100, "u1", 1, "/f.mp3");
        mgr.RemoveUpload(upload);
        Assert.Equal(0, mgr.ActiveUploadCount);
    }

    [Fact]
    public void AllProgress_EmitsOnAdd()
    {
        var mgr = new UploadManager();
        Dictionary<string, UploadProgress>? progress = null;
        using var sub = mgr.AllProgress.Subscribe(p => progress = p);
        mgr.AddUpload("f.mp3", 100, "u1", 1, "/f.mp3");
        Assert.NotNull(progress);
        Assert.Single(progress);
    }

    [Fact]
    public void HandleTransferRequest_Denied_WhenCallbackReturnsFalse()
    {
        var mgr = new UploadManager();
        var conn = new MockTransferConnection("requester");

        SoulseekMessage? sent = null;
        conn.MessageSent += msg => sent = msg;

        var request = new TransferRequest(Direction.Upload, 1, "denied.mp3", 100);
        var task = mgr.HandleTransferRequest(request, conn, (name, size) => false);

        Assert.NotNull(sent);
        Assert.Equal(PeerCode.TransferResponse, sent.Value.Code);
        var r = new ReadBuffer(sent.Value.Payload);
        Assert.Equal(1, r.ReadInt32());
    }

    [Fact]
    public void UploadProgress_Percentage()
    {
        var p = new UploadProgress("f.mp3", 50, 200, null, UploadState.Uploading);
        Assert.Equal(0.25, p.Percentage);
    }

    [Fact]
    public void UploadProgress_ZeroTotal_ReturnsZero()
    {
        var p = new UploadProgress("f.mp3", 0, 0, null, UploadState.Queued);
        Assert.Equal(0, p.Percentage);
    }
}

internal class MockTransferConnection : ITransferConnection
{
    public string Username { get; }
    private readonly Subject<SoulseekMessage> _messages = new();

    public MockTransferConnection(string username)
    {
        Username = username;
    }

    public event Action<SoulseekMessage>? MessageSent;

    public IObservable<SoulseekMessage> Messages => _messages;

    public void SendMessage(SoulseekMessage message) => MessageSent?.Invoke(message);
    public void SendRaw(int code, byte[] payload) => MessageSent?.Invoke(new SoulseekMessage(code, payload));

    public void SimulateMessage(int code, byte[] payload)
    {
        _messages.OnNext(new SoulseekMessage(code, payload));
    }

    public void Dispose() => _messages.Dispose();
}