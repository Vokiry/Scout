using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Services;

public class ChatService
{
    private readonly IServerTransport _server;
    private readonly Subject<PrivateMessage> _privateMessageSubject = new();
    private IDisposable? _messageSub;

    public ChatService(IServerTransport server)
    {
        _server = server;
    }

    public IObservable<PrivateMessage> PrivateMessages => _privateMessageSubject;

    public void Init()
    {
        _messageSub = _server.Messages.Subscribe(OnMessage);
    }

    public void SendPrivateMessage(string username, string message)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.PrivateMessage,
            new PrivateMessage(
                username,
                message,
                (int)DateTimeOffset.UtcNow.ToUnixTimeSeconds()
            ).Serialize().ToBytes()
        ));
    }

    private void OnMessage(SoulseekMessage message)
    {
        if (message.Code != ServerCode.PrivateMessage) return;

        try
        {
            var buffer = new ReadBuffer(message.Payload);
            var pm = PrivateMessage.Parse(buffer);
            _privateMessageSubject.OnNext(pm);
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