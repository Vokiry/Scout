using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Services;

namespace Soulseek.Protocol.Network;

public enum DistributedState
{
    Disconnected,
    Connecting,
    Connected,
    Disconnecting
}

public enum DistributedRole
{
    None,
    Parent,
    Child
}

public record DistributedSearchRequest(string Username, int Ticket, string Query);

public class DistributedNetwork
{
    private ISocketTransport? _parentSocket;
    private DistributedState _state = DistributedState.Disconnected;
    private DistributedRole _role = DistributedRole.None;
    private readonly Subject<DistributedSearchRequest> _searchRequestsSubject = new();
    private readonly Subject<DistributedState> _stateSubject = new();
    private IDisposable? _parentMessageSub;

    public string Username { get; }
    public int MaxChildBranches { get; } = 10;
    private readonly List<ISocketTransport> _childConnections = [];
    private readonly Func<ISocketTransport> _socketFactory;

    public DistributedNetwork(string username, Func<ISocketTransport>? socketFactory = null)
    {
        Username = username;
        _socketFactory = socketFactory ?? (() => new SocketManager());
    }

    public IObservable<DistributedState> StateChanges => _stateSubject;
    public IObservable<DistributedSearchRequest> SearchRequests => _searchRequestsSubject;
    public DistributedState State => _state;
    public DistributedRole Role => _role;
    public int ChildCount => _childConnections.Count;

    public async Task<bool> ConnectToParent(string host, int port)
    {
        SetState(DistributedState.Connecting);
        var socket = _socketFactory();
        try
        {
            await socket.Connect(host, port);
            if (socket.State != SocketState.Connected)
            {
                socket.Dispose();
                SetState(DistributedState.Disconnected);
                return false;
            }
            _parentSocket = socket;
            _role = DistributedRole.Child;
            _parentMessageSub = socket.Messages.Subscribe(OnParentMessage);
            SetState(DistributedState.Connected);
            return true;
        }
        catch
        {
            socket.Dispose();
            SetState(DistributedState.Disconnected);
            return false;
        }
    }

    public void BecomeParent()
    {
        _role = DistributedRole.Parent;
        SetState(DistributedState.Connected);
    }

    public bool AcceptChildConnection(ISocketTransport socket)
    {
        if (_childConnections.Count >= MaxChildBranches) return false;
        _childConnections.Add(socket);
        if (_role == DistributedRole.None)
            _role = DistributedRole.Parent;
        return true;
    }

    public void RelaySearchRequest(string query, int ticket, ISocketTransport? exclude = null)
    {
        if (_role != DistributedRole.Parent) return;

        var w = new WriteBuffer();
        w.WriteString(Username);
        w.WriteInt32(ticket);
        w.WriteString(query);

        foreach (var child in _childConnections)
        {
            if (child == exclude) continue;
            child.SendMessage(new SoulseekMessage(DistantCode.FileSearch, w.ToBytes()));
        }
    }

    public void RelaySearchResponse(SearchResult result, ISocketTransport? exclude = null)
    {
        if (_role != DistributedRole.Child || _parentSocket == null) return;

        var w = new WriteBuffer();
        w.WriteString(result.Username);
        w.WriteInt32(result.Ticket);
        w.WriteInt32(result.FreeUploadSlots);
        w.WriteInt32(result.UploadSpeed);
        w.WriteInt32(result.QueueLength);
        w.WriteInt32(result.Files.Count);

        foreach (var file in result.Files)
        {
            w.WriteInt32(file.Code);
            w.WriteString(file.Filename);
            w.WriteInt32(file.Size);
            w.WriteString(file.Extension);
            w.WriteInt32(file.AttributeCount);
            w.WriteInt32(0); w.WriteInt32(file.Bitrate);
            w.WriteInt32(1); w.WriteInt32(file.Duration);
            w.WriteInt32(2); w.WriteInt32(file.SampleRate);
        }

        _parentSocket.SendMessage(new SoulseekMessage(DistantCode.FileSearchReply, w.ToBytes()));
    }

    private void OnParentMessage(SoulseekMessage message)
    {
        if (message.Code != DistantCode.FileSearch) return;

        try
        {
            var buffer = new ReadBuffer(message.Payload);
            var remoteUsername = buffer.ReadString();
            var ticket = buffer.ReadInt32();
            var query = buffer.ReadString();

            _searchRequestsSubject.OnNext(new DistributedSearchRequest(remoteUsername, ticket, query));
        }
        catch
        {
            // Skip malformed messages
        }
    }

    private void SetState(DistributedState state)
    {
        if (_state == state) return;
        _state = state;
        _stateSubject.OnNext(state);
    }

    public void Disconnect()
    {
        SetState(DistributedState.Disconnecting);
        _parentMessageSub?.Dispose();
        _parentSocket?.Disconnect();
        _parentSocket?.Dispose();
        foreach (var child in _childConnections)
        {
            child.Disconnect();
            child.Dispose();
        }
        _childConnections.Clear();
        _parentSocket = null;
        _role = DistributedRole.None;
        SetState(DistributedState.Disconnected);
    }

    public void Dispose()
    {
        Disconnect();
        _searchRequestsSubject.Dispose();
        _stateSubject.Dispose();
    }
}