using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Connection;

public enum ServerConnectionState
{
    Disconnected,
    Connecting,
    Connected,
    Reconnecting
}

public record ConnectionInfo(
    bool Authenticated = false,
    int? LocalIp = null,
    int? LocalPort = null,
    bool Obfuscated = false,
    bool ServerShuttingDown = false,
    string? Message = null
);

public interface IServerTransport
{
    IObservable<ServerConnectionState> StateChanges { get; }
    IObservable<SoulseekMessage> Messages { get; }
    IObservable<ConnectionInfo> ConnectionInfo { get; }
    ServerConnectionState State { get; }
    bool Authenticated { get; }
    string? Username { get; }
    void Init();
    void SetServer(string host, int port);
    Task Connect(string username, string password);
    Task Disconnect();
    void SendMessage(SoulseekMessage message);
    void SendRaw(int code, byte[] payload);
    void Dispose();
}

public class ServerConnection : IServerTransport
{
    private readonly ISocketTransport _socket;
    private readonly ReconnectionManager _reconnector;

    private bool _authenticated;
    private string? _username;
    private string _serverHost = "server.slsknet.org";
    private int _serverPort = 2244;

    private readonly Subject<ServerConnectionState> _stateSubject = new();
    private readonly Subject<SoulseekMessage> _messageSubject = new();
    private readonly Subject<ConnectionInfo> _connectionInfoSubject = new();
    private ServerConnectionState _state = ServerConnectionState.Disconnected;

    private IDisposable? _socketStateSub;
    private IDisposable? _socketMessageSub;

    public ServerConnection(ISocketTransport? socketTransport = null)
    {
        _socket = socketTransport ?? new SocketManager();
        _reconnector = new ReconnectionManager(_socket);
    }

    public IObservable<ServerConnectionState> StateChanges => _stateSubject;
    public IObservable<SoulseekMessage> Messages => _messageSubject;
    public IObservable<ConnectionInfo> ConnectionInfo => _connectionInfoSubject;
    public ServerConnectionState State => _state;
    public bool Authenticated => _authenticated;
    public string? Username => _username;

    public void Init()
    {
        _socketStateSub = _socket.StateChanges.Subscribe(OnSocketStateChange);
        _socketMessageSub = _socket.Messages.Subscribe(OnMessage);
    }

    public void SetServer(string host, int port)
    {
        _serverHost = host;
        _serverPort = port;
    }

    public async Task Connect(string username, string password)
    {
        _username = username;
        SetState(ServerConnectionState.Connecting);
        _reconnector.Start(_serverHost, _serverPort);

        await _socket.Connect(_serverHost, _serverPort);
        SendLogin(username, password);
    }

    private void SendLogin(string username, string password)
    {
        var login = new LoginRequest(username, password);
        _socket.SendMessage(new SoulseekMessage(login.Code, login.Serialize().ToBytes()));
    }

    public async Task Disconnect()
    {
        _reconnector.Stop();
        await _socket.Disconnect();
        _authenticated = false;
        SetState(ServerConnectionState.Disconnected);
    }

    public void SendMessage(SoulseekMessage message)
    {
        _socket.SendMessage(message);
    }

    public void SendRaw(int code, byte[] payload)
    {
        _socket.SendRaw(code, payload);
    }

    private void OnSocketStateChange(SocketStateChanged eventArgs)
    {
        switch (eventArgs.State)
        {
            case SocketState.Disconnected:
                _authenticated = false;
                if (_reconnector.State.IsRunning)
                    SetState(ServerConnectionState.Reconnecting);
                else
                    SetState(ServerConnectionState.Disconnected);
                break;
            case SocketState.Connecting:
                SetState(ServerConnectionState.Connecting);
                break;
            case SocketState.Connected:
                SetState(ServerConnectionState.Connected);
                break;
        }
    }

    private void OnMessage(SoulseekMessage message)
    {
        switch (message.Code)
        {
            case ServerCode.LoginResponse:
                HandleLoginResponse(message);
                break;
            case ServerCode.ServerShuttingDown:
                HandleServerShutdown(message);
                break;
            case ServerCode.Ping:
                RespondPing();
                break;
            default:
                _messageSubject.OnNext(message);
                break;
        }
    }

    private void HandleLoginResponse(SoulseekMessage message)
    {
        var buffer = new ReadBuffer(message.Payload);
        var response = LoginResponse.Parse(buffer);
        _authenticated = response.Success;
        _connectionInfoSubject.OnNext(new ConnectionInfo(
            Authenticated: response.Success,
            LocalIp: response.Ip,
            LocalPort: response.Port,
            Obfuscated: response.Obfuscated
        ));
    }

    private void HandleServerShutdown(SoulseekMessage message)
    {
        _connectionInfoSubject.OnNext(new ConnectionInfo(
            Authenticated: _authenticated,
            ServerShuttingDown: true,
            Message: new ReadBuffer(message.Payload).ReadString()
        ));
    }

    private void RespondPing()
    {
        SendMessage(new SoulseekMessage(ServerCode.Pong, new WriteBuffer().ToBytes()));
    }

    private void SetState(ServerConnectionState state)
    {
        if (_state == state) return;
        _state = state;
        _stateSubject.OnNext(state);
    }

    public void Dispose()
    {
        _socketStateSub?.Dispose();
        _socketMessageSub?.Dispose();
        _reconnector.Dispose();
        _socket.Dispose();
        _stateSubject.Dispose();
        _messageSubject.Dispose();
        _connectionInfoSubject.Dispose();
    }
}