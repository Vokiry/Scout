using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Peer;

public enum PeerConnectionState
{
    Disconnected,
    Connecting,
    Connected,
    Obfuscating
}

public enum PeerConnectionType
{
    Incoming,
    Outgoing
}

public interface ITransferConnection
{
    string Username { get; }
    IObservable<SoulseekMessage> Messages { get; }
    void SendMessage(SoulseekMessage message);
    void SendRaw(int code, byte[] payload);
}

public class PeerConnection : ITransferConnection
{
    public string Username { get; }
    public int Ip { get; }
    public int Port { get; }
    public PeerConnectionType Type { get; }
    public PeerConnectionState State => _state;

    private readonly SocketManager _socketManager;
    private PeerConnectionState _state = PeerConnectionState.Disconnected;
    private IDisposable? _subscription;

    private readonly Subject<PeerConnectionState> _stateSubject = new();
    private readonly Subject<SoulseekMessage> _messagesSubject = new();

    public PeerConnection(string username, int ip, int port, PeerConnectionType type, SocketManager socketManager)
    {
        Username = username;
        Ip = ip;
        Port = port;
        Type = type;
        _socketManager = socketManager;
    }

    public IObservable<PeerConnectionState> StateChanges => _stateSubject;
    public IObservable<SoulseekMessage> Messages => _messagesSubject;

    private string IntToIp(int value)
    {
        return $"{(value >> 24) & 0xFF}.{(value >> 16) & 0xFF}.{(value >> 8) & 0xFF}.{value & 0xFF}";
    }

    public async Task Connect()
    {
        SetState(PeerConnectionState.Connecting);
        try
        {
            await _socketManager.Connect(IntToIp(Ip), Port);
            SetState(PeerConnectionState.Connected);
            _subscription = _socketManager.Messages.Subscribe(OnMessage);
        }
        catch
        {
            SetState(PeerConnectionState.Disconnected);
        }
    }

    private void OnMessage(SoulseekMessage message)
    {
        _messagesSubject.OnNext(message);
    }

    public void SendMessage(SoulseekMessage message)
    {
        _socketManager.SendMessage(message);
    }

    public void SendRaw(int code, byte[] payload)
    {
        _socketManager.SendRaw(code, payload);
    }

    public async Task Disconnect()
    {
        _subscription?.Dispose();
        await _socketManager.Disconnect();
        SetState(PeerConnectionState.Disconnected);
    }

    private void SetState(PeerConnectionState state)
    {
        if (_state == state) return;
        _state = state;
        _stateSubject.OnNext(state);
    }

    public void Dispose()
    {
        _subscription?.Dispose();
        _socketManager.Dispose();
        _stateSubject.Dispose();
        _messagesSubject.Dispose();
    }
}