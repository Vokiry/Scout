using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Peer;

namespace Soulseek.Protocol.Services;

public class BrowseService
{
    public async Task<FolderContentsReply> BrowseUser(
        ITransferConnection connection,
        string directory = "",
        TimeSpan? timeout = null)
    {
        timeout ??= TimeSpan.FromSeconds(30);

        connection.SendMessage(new SoulseekMessage(
            PeerCode.FolderContents,
            new FolderContentsRequest(directory).Serialize().ToBytes()
        ));

        var tcs = new TaskCompletionSource<FolderContentsReply>(TaskCreationOptions.RunContinuationsAsynchronously);
        IDisposable? sub = null;
        Timer? timer = null;

        timer = new Timer(_ =>
        {
            tcs.TrySetException(new TimeoutException($"Browse request timed out after {timeout}"));
        }, null, timeout.Value, Timeout.InfiniteTimeSpan);

        sub = connection.MessageStream.Subscribe(new BrowseObserver(message =>
        {
            if (message.Code != PeerCode.FolderContentsReply) return;
            try
            {
                var reply = FolderContentsReply.Parse(new ReadBuffer(message.Payload));
                tcs.TrySetResult(reply);
            }
            catch (Exception e)
            {
                tcs.TrySetException(e);
            }
        }, ex =>
        {
            tcs.TrySetException(new Exception("Connection closed while browsing", ex));
        }, () =>
        {
            tcs.TrySetException(new Exception("Connection closed while browsing"));
        }));

        try
        {
            return await tcs.Task.ConfigureAwait(false);
        }
        finally
        {
            sub?.Dispose();
            timer?.Dispose();
        }
    }

    public void Dispose() { }

    private sealed class BrowseObserver : IObserver<SoulseekMessage>
    {
        private readonly Action<SoulseekMessage> _onNext;
        private readonly Action<Exception> _onError;
        private readonly Action _onCompleted;

        public BrowseObserver(Action<SoulseekMessage> onNext, Action<Exception> onError, Action onCompleted)
        {
            _onNext = onNext;
            _onError = onError;
            _onCompleted = onCompleted;
        }

        public void OnNext(SoulseekMessage value) => _onNext(value);
        public void OnError(Exception error) => _onError(error);
        public void OnCompleted() => _onCompleted();
    }
}