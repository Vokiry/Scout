using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;

namespace Soulseek.Protocol.Services;

public record SearchResult(
    string Username,
    int Ticket,
    int FreeUploadSlots,
    int UploadSpeed,
    int QueueLength,
    List<SearchResultFile> Files
);

public class SearchService
{
    private readonly IServerTransport _server;
    private readonly Subject<SearchResult> _resultsSubject = new();
    private int _nextTicket = 1;
    private IDisposable? _messageSub;

    public SearchService(IServerTransport server)
    {
        _server = server;
    }

    public IObservable<SearchResult> Results => _resultsSubject;

    public void Init()
    {
        _messageSub = _server.MessageStream.Subscribe(OnMessage);
    }

    public int Search(string query)
    {
        var ticket = _nextTicket++;
        _server.SendMessage(new SoulseekMessage(
            ServerCode.SearchRequest,
            new SearchRequest(query, ticket).Serialize().ToBytes()
        ));
        return ticket;
    }

    private void OnMessage(SoulseekMessage message)
    {
        if (message.Code != ServerCode.SearchResponse &&
            message.Code != ServerCode.UserSearchResponse)
            return;

        try
        {
            var buffer = new ReadBuffer(message.Payload);
            SearchResponseData response;
            try
            {
                response = SearchResponseData.Parse(buffer);
            }
            catch
            {
                response = SearchResponseData.ParseOld(new ReadBuffer(message.Payload));
            }

            _resultsSubject.OnNext(new SearchResult(
                response.Username,
                response.Ticket,
                response.FreeUploadSlots,
                response.UploadSpeed,
                response.QueueLength,
                response.Files
            ));
        }
        catch
        {
            // Skip malformed search responses
        }
    }

    public void Dispose()
    {
        _messageSub?.Dispose();
    }
}