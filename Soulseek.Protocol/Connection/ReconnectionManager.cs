namespace Soulseek.Protocol.Connection;

public class ReconnectionConfig
{
    public TimeSpan BaseDelay { get; init; } = TimeSpan.FromSeconds(1);
    public TimeSpan MaxDelay { get; init; } = TimeSpan.FromSeconds(60);
    public double Multiplier { get; init; } = 2.0;
    public int MaxAttempts { get; init; } = -1;
    public int JitterMs { get; init; } = 1000;
}

public record ReconnectionState(
    bool IsRunning,
    int Attempt,
    TimeSpan NextDelay,
    string? LastError = null,
    bool IsFinal = false
);

public class ReconnectionManager
{
    private readonly ISocketTransport _socketTransport;
    private readonly ReconnectionConfig _config;

    private bool _isRunning;
    private int _attempt;
    private Timer? _timer;
    private string? _host;
    private int? _port;
    private IDisposable? _stateSub;

    private readonly Subject<ReconnectionState> _stateSubject = new();

    public ReconnectionManager(ISocketTransport socketTransport, ReconnectionConfig? config = null)
    {
        _socketTransport = socketTransport;
        _config = config ?? new ReconnectionConfig();
    }

    public IObservable<ReconnectionState> StateChanges => _stateSubject;
    public ReconnectionState State => new(_isRunning, _attempt, CalculateDelay());

    public void Start(string host, int port)
    {
        _host = host;
        _port = port;
        _isRunning = true;
        _attempt = 0;
        _stateSub = _socketTransport.StateChanges.Subscribe(OnSocketStateChange);
        TryReconnect();
    }

    public void Stop()
    {
        _isRunning = false;
        _timer?.Dispose();
        _timer = null;
        _attempt = 0;
        _stateSub?.Dispose();
        _stateSub = null;
        EmitState();
    }

    public void Reset()
    {
        _attempt = 0;
        _timer?.Dispose();
        EmitState();
    }

    private void OnSocketStateChange(SocketStateChanged eventArgs)
    {
        if (eventArgs.State == SocketState.Connected)
        {
            _isRunning = false;
            _attempt = 0;
            _timer?.Dispose();
            EmitState();
        }
        else if (eventArgs.State == SocketState.Disconnected && _isRunning)
        {
            ScheduleReconnect(eventArgs.ErrorMessage);
        }
    }

    private void ScheduleReconnect(string? errorMessage = null)
    {
        _timer?.Dispose();
        var delay = CalculateDelay();
        _attempt++;
        EmitState(errorMessage: errorMessage);

        _timer = new Timer(_ => TryReconnect(), null, delay, Timeout.InfiniteTimeSpan);
    }

    private void TryReconnect()
    {
        if (!_isRunning || _host == null || _port == null) return;

        if (_config.MaxAttempts >= 0 && _attempt >= _config.MaxAttempts)
        {
            _isRunning = false;
            EmitState(isFinal: true);
            return;
        }

        _ = _socketTransport.Connect(_host!, _port!.Value);
    }

    private TimeSpan CalculateDelay()
    {
        if (_attempt == 0) return TimeSpan.Zero;
        var baseMs = _config.BaseDelay.TotalMilliseconds;
        var maxMs = _config.MaxDelay.TotalMilliseconds;
        var delay = Math.Min(baseMs * Math.Pow(_config.Multiplier, _attempt - 1), maxMs);
        var jitter = _config.JitterMs > 0
            ? Random.Shared.Next(_config.JitterMs) - (_config.JitterMs / 2)
            : 0;
        return TimeSpan.FromMilliseconds(delay + jitter);
    }

    private void EmitState(string? errorMessage = null, bool isFinal = false)
    {
        _stateSubject.OnNext(new ReconnectionState(
            _isRunning, _attempt, CalculateDelay(), errorMessage, isFinal));
    }

    public void Dispose()
    {
        Stop();
        _stateSubject.Dispose();
    }
}