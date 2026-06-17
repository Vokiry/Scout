using Xunit;

namespace Soulseek.Protocol.Tests;

public class SubjectTests
{
    [Fact]
    public void Subscribe_OnNext_DeliversValue()
    {
        var subject = new Subject<int>();
        var result = 0;
        using var sub = subject.Subscribe(new DelegateObserver<int>(v => result = v, _ => { }, () => { }));
        subject.OnNext(42);
        Assert.Equal(42, result);
    }

    [Fact]
    public void Subscribe_MultipleObservers_AllReceiveValues()
    {
        var subject = new Subject<int>();
        var results = new List<int>();
        var lockObj = new object();

        var sub1 = subject.Subscribe(new DelegateObserver<int>(v => { lock (lockObj) results.Add(v); }, _ => { }, () => { }));
        var sub2 = subject.Subscribe(new DelegateObserver<int>(v => { lock (lockObj) results.Add(v); }, _ => { }, () => { }));

        subject.OnNext(7);
        Assert.Equal(2, results.Count);
        Assert.All(results, r => Assert.Equal(7, r));

        sub1.Dispose();
        sub2.Dispose();
    }

    [Fact]
    public void Unsubscribe_StopsReceiving()
    {
        var subject = new Subject<int>();
        var received = false;
        var sub = subject.Subscribe(new DelegateObserver<int>(v => received = true, _ => { }, () => { }));
        sub.Dispose();
        subject.OnNext(1);
        Assert.False(received);
    }

    [Fact]
    public void Dispose_CallsOnCompleted()
    {
        var subject = new Subject<int>();
        var completed = false;
        using var sub = subject.Subscribe(new DelegateObserver<int>(_ => {}, _ => { }, () => completed = true));
        subject.Dispose();
        Assert.True(completed);
    }

    [Fact]
    public void OnNext_AfterDispose_DoesNotThrow()
    {
        var subject = new Subject<int>();
        subject.Dispose();
        subject.OnNext(1);
    }

    [Fact]
    public void Dispose_Idempotent()
    {
        var subject = new Subject<int>();
        subject.Dispose();
        subject.Dispose();
    }

    [Fact]
    public void Subscribe_AfterDispose_CallsOnCompletedImmediately()
    {
        var subject = new Subject<int>();
        subject.Dispose();
        var completed = false;
        using var sub = subject.Subscribe(new DelegateObserver<int>(_ => {}, _ => { }, () => completed = true));
        Assert.True(completed);
    }

    [Fact]
    public void OnError_DeliversToSubscribers()
    {
        var subject = new Subject<string>();
        Exception? captured = null;
        using var sub = subject.Subscribe(new DelegateObserver<string>(_ => {}, e => captured = e, () => { }));
        var error = new InvalidOperationException("test");
        subject.OnError(error);
        Assert.Same(error, captured);
    }

    [Fact]
    public void OnCompleted_DeliversToSubscribers()
    {
        var subject = new Subject<int>();
        var completed = false;
        using var sub = subject.Subscribe(new DelegateObserver<int>(_ => {}, _ => { }, () => completed = true));
        subject.OnCompleted();
        Assert.True(completed);
    }

    [Fact]
    public void Subscribe_ReturnsDisposable()
    {
        var subject = new Subject<int>();
        var sub = subject.Subscribe(new DelegateObserver<int>(_ => {}, _ => { }, () => {}));
        Assert.NotNull(sub);
        sub.Dispose();
    }

    [Fact]
    public void MultipleDispose_Called_DoesNotThrow()
    {
        var subject = new Subject<int>();
        var sub = subject.Subscribe(new DelegateObserver<int>(_ => {}, _ => { }, () => {}));
        sub.Dispose();
        sub.Dispose();
    }
}

internal sealed class DelegateObserver<T> : IObserver<T>
{
    private readonly Action<T> _onNext;
    private readonly Action<Exception> _onError;
    private readonly Action _onCompleted;

    public DelegateObserver(Action<T> onNext, Action<Exception> onError, Action onCompleted)
    {
        _onNext = onNext;
        _onError = onError;
        _onCompleted = onCompleted;
    }

    public void OnNext(T value) => _onNext(value);
    public void OnError(Exception error) => _onError(error);
    public void OnCompleted() => _onCompleted();
}