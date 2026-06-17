using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Services;

public class UserService
{
    private readonly IServerTransport _server;
    private readonly Subject<UserStatusMessage> _userStatusSubject = new();
    private readonly Subject<PeerAddressResponse> _peerAddressSubject = new();
    private IDisposable? _messageSub;

    public UserService(IServerTransport server)
    {
        _server = server;
    }

    public IObservable<UserStatusMessage> UserStatus => _userStatusSubject;
    public IObservable<PeerAddressResponse> PeerAddressResponses => _peerAddressSubject;

    public void Init()
    {
        _messageSub = _server.MessageStream.Subscribe(OnMessage);
    }

    public void AddUser(string username)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.AddUser,
            new AddUser(username).Serialize().ToBytes()
        ));
    }

    public void GetPeerAddress(string username)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.GetPeerAddress,
            new GetPeerAddress(username).Serialize().ToBytes()
        ));
    }

    private void OnMessage(SoulseekMessage message)
    {
        try
        {
            if (message.Code == ServerCode.StatusResponse)
            {
                var buffer = new ReadBuffer(message.Payload);
                var status = UserStatusMessage.Parse(buffer);
                _userStatusSubject.OnNext(status);
            }
            else if (message.Code == ServerCode.GetPeerAddress)
            {
                var buffer = new ReadBuffer(message.Payload);
                var addr = PeerAddressResponse.Parse(buffer);
                _peerAddressSubject.OnNext(addr);
            }
        }
        catch
        {
            // Skip malformed messages
        }
    }

    public void Dispose()
    {
        _messageSub?.Dispose();
    }
}