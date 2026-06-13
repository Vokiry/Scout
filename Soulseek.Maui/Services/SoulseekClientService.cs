using Soulseek.Protocol;
using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Peer;
using Soulseek.Protocol.Services;
using Soulseek.Protocol.Transfer;

namespace Soulseek.Maui.Services;

public class SoulseekClientService
{
    private bool _initialized;

    public SoulseekClient Client { get; } = new();
    public bool IsConnected => Client.Authenticated;
    public string? Username => Client.Username;

    public void EnsureInit()
    {
        if (!_initialized)
        {
            Client.Init();
            _initialized = true;
        }
    }

    public async Task ConnectAsync(string username, string password)
    {
        EnsureInit();
        await Client.Connect(username, password);
    }

    public void Disconnect()
    {
        try { _ = Client.Disconnect(); } catch { }
    }

    public int Search(string query) => Client.Search(query);

    public void SendPrivateMessage(string username, string message) =>
        Client.SendPrivateMessage(username, message);

    public void JoinRoom(string roomName) => Client.JoinRoom(roomName);
    public void LeaveRoom(string roomName) => Client.LeaveRoom(roomName);
    public void SendRoomMessage(string roomName, string message) =>
        Client.SendRoomMessage(roomName, message);
    public void RequestRoomList() => Client.RequestRoomList();

    public void AddWishlistItem(string phrase) => Client.AddWishlistItem(phrase);
    public void RemoveWishlistItem(string phrase) => Client.RemoveWishlistItem(phrase);
    public int WishlistSearch(string query) => Client.WishlistSearch(query);

    public async Task<FolderContentsReply?> BrowseUserAsync(string username)
    {
        var tcs = new TaskCompletionSource<PeerAddressResponse?>(TaskCreationOptions.RunContinuationsAsynchronously);
        IDisposable? sub = null;
        sub = Client.PeerAddressResponses.Subscribe(addr =>
        {
            if (addr.Username == username)
            {
                tcs.TrySetResult(addr);
                sub?.Dispose();
            }
        });
        Client.AddUser(username);
        Client.GetPeerAddress(username);
        var timeout = TimeSpan.FromSeconds(15);
        PeerAddressResponse? addr;
        try { addr = await tcs.Task.WaitAsync(timeout); }
        catch { return null; }
        if (addr == null) return null;
        try { return await Client.BrowseUser(username, addr.Ip, addr.Port, ""); }
        catch { return null; }
    }

    public async Task<bool> DownloadFileAsync(string filename, int size, string username, int fileCode)
    {
        try
        {
            var tcs = new TaskCompletionSource<PeerAddressResponse?>(TaskCreationOptions.RunContinuationsAsynchronously);
            IDisposable? sub = null;
            sub = Client.PeerAddressResponses.Subscribe(addr =>
            {
                if (addr.Username == username) { tcs.TrySetResult(addr); sub?.Dispose(); }
            });
            Client.AddUser(username);
            Client.GetPeerAddress(username);
            var addr = await tcs.Task.WaitAsync(TimeSpan.FromSeconds(15));
            if (addr == null) return false;

            var connection = await Client.ConnectToPeer(username, addr.Ip, addr.Port);
            if (connection == null) return false;

            var safeName = SanitizeFilename(Path.GetFileName(filename));
            var dlDir = GetDownloadDirectory();
            Directory.CreateDirectory(dlDir);
            var localPath = Path.Combine(dlDir, safeName);

            await Client.RequestDownload(filename, size, username, fileCode, connection, localPath);
            return true;
        }
        catch { return false; }
    }

    private static string SanitizeFilename(string name)
    {
        var invalid = Path.GetInvalidFileNameChars();
        return string.Concat(name.Select(c => invalid.Contains(c) ? '_' : c));
    }

    public static string GetDownloadDirectory()
    {
        var dir = Android.OS.Environment.GetExternalStoragePublicDirectory(
            Android.OS.Environment.DirectoryDownloads)?.AbsolutePath;
        if (dir == null)
            dir = Path.Combine(
                Android.OS.Environment.ExternalStorageDirectory?.AbsolutePath ?? "/sdcard",
                "Download");
        return Path.Combine(dir, "Scout");
    }

    public void Dispose()
    {
        try { Client.Dispose(); } catch { }
    }
}
