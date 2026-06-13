using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Services;

public class WishlistService
{
    private readonly IServerTransport _server;
    private readonly Subject<WishlistReply> _resultsSubject = new();
    private int _nextTicket = 1;
    private IDisposable? _messageSub;

    public WishlistService(IServerTransport server)
    {
        _server = server;
    }

    public IObservable<WishlistReply> WishlistResults => _resultsSubject;

    public void Init()
    {
        _messageSub = _server.MessageStream.Subscribe(OnMessage);
    }

    public int WishlistSearch(string query)
    {
        var ticket = _nextTicket++;
        _server.SendMessage(new SoulseekMessage(
            ServerCode.Wishes,
            new WishlistSearchRequest(ticket, query).Serialize().ToBytes()
        ));
        return ticket;
    }

    public void AddWishlistItem(string phrase)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.WishlistInclusion,
            new WishlistInclusion(true, phrase).Serialize().ToBytes()
        ));
    }

    public void RemoveWishlistItem(string phrase)
    {
        _server.SendMessage(new SoulseekMessage(
            ServerCode.WishlistInclusion,
            new WishlistInclusion(false, phrase).Serialize().ToBytes()
        ));
    }

    private void OnMessage(SoulseekMessage message)
    {
        if (message.Code != ServerCode.WishReply) return;

        try
        {
            var reply = WishlistReply.Parse(new ReadBuffer(message.Payload));
            _resultsSubject.OnNext(reply);
        }
        catch
        {
            // Skip malformed wishlist replies
        }
    }

    public void Dispose()
    {
        _messageSub?.Dispose();
    }
}