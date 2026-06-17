namespace Soulseek.Protocol;

public static class ObservableExtensions
{
    public static IDisposable Subscribe<T>(this IObservable<T> observable, Action<T> onNext)
    {
        return observable.Subscribe(new AnonymousObserver<T>(onNext, null, null));
    }

    public static IDisposable Subscribe<T>(this IObservable<T> observable, Action<T> onNext, Action<Exception> onError)
    {
        return observable.Subscribe(new AnonymousObserver<T>(onNext, onError, null));
    }

    public static IDisposable Subscribe<T>(this IObservable<T> observable, Action<T> onNext, Action onCompleted)
    {
        return observable.Subscribe(new AnonymousObserver<T>(onNext, null, onCompleted));
    }

    private sealed class AnonymousObserver<T> : IObserver<T>
    {
        private readonly Action<T>? _onNext;
        private readonly Action<Exception>? _onError;
        private readonly Action? _onCompleted;

        public AnonymousObserver(Action<T>? onNext, Action<Exception>? onError, Action? onCompleted)
        {
            _onNext = onNext;
            _onError = onError;
            _onCompleted = onCompleted;
        }

        public void OnNext(T value) => _onNext?.Invoke(value);
        public void OnError(Exception error) => _onError?.Invoke(error);
        public void OnCompleted() => _onCompleted?.Invoke();
    }
}
