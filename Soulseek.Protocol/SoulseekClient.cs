using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Peer;
using Soulseek.Protocol.Services;
using Soulseek.Protocol.Transfer;

namespace Soulseek.Protocol;

public class SoulseekClient
{
    private readonly IServerTransport _server;
    private readonly DownloadManager _downloadManager;
    private readonly UploadManager _uploadManager;
    private readonly Dictionary<string, PeerConnection> _activePeers = new();
    private PeerListener? _peerListener;

    public AuthService Auth { get; }
    public SearchService SearchService { get; }
    public ChatService Chat { get; }
    public UserService Users { get; }
    public BrowseService BrowseService { get; }
    public WishlistService WishlistService { get; }
    public RoomChatService RoomChat { get; }
    public UploadManager UploadManager => _uploadManager;
    public DownloadManager DownloadManager => _downloadManager;

    public SoulseekClient(
        IServerTransport? server = null,
        AuthService? auth = null,
        SearchService? searchService = null,
        ChatService? chat = null,
        UserService? users = null,
        BrowseService? browseService = null,
        WishlistService? wishlistService = null,
        RoomChatService? roomChat = null)
    {
        _server = server ?? new ServerConnection();
        Auth = auth ?? new AuthService(_server);
        SearchService = searchService ?? new SearchService(_server);
        Chat = chat ?? new ChatService(_server);
        Users = users ?? new UserService(_server);
        BrowseService = browseService ?? new BrowseService();
        WishlistService = wishlistService ?? new WishlistService(_server);
        RoomChat = roomChat ?? new RoomChatService(_server);
        _downloadManager = new DownloadManager();
        _uploadManager = new UploadManager();
    }

    public IObservable<ServerConnectionState> ConnectionState => Auth.ConnectionState;
    public IObservable<SearchResult> SearchResults => SearchService.Results;
    public IObservable<PrivateMessage> PrivateMessages => Chat.PrivateMessages;
    public IObservable<UserStatusMessage> UserStatus => Users.UserStatus;
    public IObservable<Dictionary<string, DownloadProgress>> DownloadProgress => _downloadManager.AllProgress;
    public IObservable<WishlistReply> WishlistResults => WishlistService.WishlistResults;
    public IObservable<RoomMessageData> RoomMessages => RoomChat.RoomMessages;
    public IObservable<UserJoinedRoom> RoomUserJoined => RoomChat.UserJoined;
    public IObservable<UserLeftRoom> RoomUserLeft => RoomChat.UserLeft;
    public IObservable<RoomList> RoomList => RoomChat.RoomList;
    public IObservable<ConnectionInfo> ConnectionInfo => Auth.ConnectionInfo;
    public IObservable<PeerAddressResponse> PeerAddressResponses => Users.PeerAddressResponses;
    public bool Authenticated => Auth.Authenticated;
    public string? Username => Auth.Username;

    public void Init()
    {
        Auth.Init();
        SearchService.Init();
        Chat.Init();
        Users.Init();
        WishlistService.Init();
        RoomChat.Init();
    }

    public Task Connect(string username, string password) => Auth.Connect(username, password);

    public async Task Disconnect()
    {
        await StopListening();
        await Auth.Disconnect();
        foreach (var peer in _activePeers.Values)
            await peer.Disconnect();
        _activePeers.Clear();
    }

    public void SetServer(string host, int port)
    {
        _server.SetServer(host, port);
    }

    public void SetListenPort(int port)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.SetListenPort,
            new SetListenPort(port).Serialize().ToBytes()
        ));
    }

    public async Task StartListening(int port)
    {
        if (_peerListener != null)
            await _peerListener.Stop();
        _peerListener = new PeerListener(_uploadManager);
        await _peerListener.Start(port);
        SetListenPort(port);
    }

    public async Task StopListening()
    {
        if (_peerListener != null)
        {
            await _peerListener.Stop();
            _peerListener = null;
        }
    }

    public int Search(string query) => SearchService.Search(query);
    public void AddUser(string username) => Users.AddUser(username);
    public void GetPeerAddress(string username) => Users.GetPeerAddress(username);

    public void SendPrivateMessage(string username, string message)
    {
        Chat.SendPrivateMessage(username, message);
    }

    public void CheckDownloadQueue(List<string> usernames)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.CheckDownloadQueue,
            new CheckDownloadQueue(usernames).Serialize().ToBytes()
        ));
    }

    public async Task<PeerConnection?> ConnectToPeer(string username, int ip, int port)
    {
        if (_activePeers.TryGetValue(username, out var existing))
        {
            await existing.Disconnect();
            _activePeers.Remove(username);
        }

        var socketManager = new SocketManager();
        var peer = new PeerConnection(username, ip, port, PeerConnectionType.Outgoing, socketManager);

        await peer.Connect();
        _activePeers[username] = peer;
        return peer;
    }

    public void EnqueueDownload(string filename, int size, string username, int fileCode, string? localPath = null)
    {
        _downloadManager.AddDownload(filename, size, username, fileCode, localPath);
    }

    public async Task RequestDownload(string filename, int size, string username, int fileCode, PeerConnection connection, string? localPath = null)
    {
        var download = _downloadManager.AddDownload(filename, size, username, fileCode, localPath);
        await _downloadManager.StartDownload(download, connection);
    }

    public async Task<FolderContentsReply> BrowseUser(string username, int ip, int port, string directory = "")
    {
        var connection = await ConnectToPeer(username, ip, port);
        if (connection == null)
            throw new Exception($"Failed to connect to peer {username}");
        return await BrowseService.BrowseUser(connection, directory);
    }

    public int WishlistSearch(string query) => WishlistService.WishlistSearch(query);
    public void AddWishlistItem(string phrase) => WishlistService.AddWishlistItem(phrase);
    public void RemoveWishlistItem(string phrase) => WishlistService.RemoveWishlistItem(phrase);
    public void JoinRoom(string roomName) => RoomChat.JoinRoom(roomName);
    public void LeaveRoom(string roomName) => RoomChat.LeaveRoom(roomName);
    public void SendRoomMessage(string roomName, string message) => RoomChat.SendMessage(roomName, message);
    public void RequestRoomList() => RoomChat.RequestRoomList();
    public void SetRoomTicker(string roomName, string ticker) => RoomChat.SetRoomTicker(roomName, ticker);
    public void RemoveRoomTicker(string roomName) => RoomChat.RemoveRoomTicker(roomName);

    public void Dispose()
    {
        SearchService.Dispose();
        Chat.Dispose();
        Users.Dispose();
        BrowseService.Dispose();
        WishlistService.Dispose();
        RoomChat.Dispose();
        Auth.Dispose();
        _peerListener?.Dispose();
        _downloadManager.Dispose();
        _uploadManager.Dispose();
        foreach (var peer in _activePeers.Values)
            peer.Dispose();
        _activePeers.Clear();
    }
}