namespace Soulseek.Protocol;

public class Subject<T> : IObservable<T>, IDisposable
{
    private readonly object _lock = new();
    private List<IObserver<T>> _observers = new();
    private bool _isDisposed;

    public IDisposable Subscribe(IObserver<T> observer)
    {
        lock (_lock)
        {
            if (_isDisposed)
            {
                observer.OnCompleted();
                return new Unsubscriber(() => { });
            }
            _observers.Add(observer);
        }
        return new Unsubscriber(() =>
        {
            lock (_lock) _observers.Remove(observer);
        });
    }

    public void OnNext(T value)
    {
        List<IObserver<T>> snapshot;
        lock (_lock)
        {
            if (_isDisposed) return;
            snapshot = new List<IObserver<T>>(_observers);
        }
        foreach (var observer in snapshot)
            observer.OnNext(value);
    }

    public void OnError(Exception error)
    {
        List<IObserver<T>> snapshot;
        lock (_lock)
        {
            if (_isDisposed) return;
            snapshot = new List<IObserver<T>>(_observers);
        }
        foreach (var observer in snapshot)
            observer.OnError(error);
    }

    public void OnCompleted()
    {
        List<IObserver<T>> snapshot;
        lock (_lock)
        {
            if (_isDisposed) return;
            snapshot = new List<IObserver<T>>(_observers);
        }
        foreach (var observer in snapshot)
            observer.OnCompleted();
    }

    public void Dispose()
    {
        List<IObserver<T>>? snapshot;
        lock (_lock)
        {
            if (_isDisposed) return;
            _isDisposed = true;
            snapshot = new List<IObserver<T>>(_observers);
            _observers.Clear();
        }
        foreach (var observer in snapshot)
            observer.OnCompleted();
    }

    private class Unsubscriber : IDisposable
    {
        private readonly Action _unsubscribe;
        public Unsubscriber(Action unsubscribe) => _unsubscribe = unsubscribe;
        public void Dispose() => _unsubscribe();
    }
}