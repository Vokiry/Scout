using System.Net;
using System.Net.Sockets;

namespace Soulseek.Protocol.Connection;

public enum SocketState
{
    Disconnected,
    Connecting,
    Connected
}

public enum SocketErrorType
{
    None,
    ConnectionRefused,
    DnsFailure,
    Timeout,
    TlsError,
    NetworkUnreachable,
    ConnectionReset,
    Unknown
}

public record SocketStateChanged(SocketState State, SocketErrorType ErrorType = SocketErrorType.None, string? ErrorMessage = null);

public record MessageReceived(Messages.SoulseekMessage Message);

public interface ISocketTransport
{
    SocketState State { get; }
    IObservable<Messages.SoulseekMessage> Messages { get; }
    IObservable<SocketStateChanged> StateChanges { get; }
    Task Connect(string host, int port, TimeSpan? timeout = null);
    Task Disconnect();
    void SendMessage(Messages.SoulseekMessage message);
    void SendRaw(int code, byte[] payload);
    void Dispose();
}

public class SocketManager : ISocketTransport, IDisposable
{
    private TcpClient? _tcpClient;
    private NetworkStream? _stream;
    private SocketState _state = SocketState.Disconnected;
    private CancellationTokenSource? _cts;
    private Task? _readLoopTask;
    private readonly SemaphoreSlim _writeLock = new(1, 1);

    private readonly Subject<Messages.SoulseekMessage> _messageSubject = new();
    private readonly Subject<SocketStateChanged> _stateSubject = new();
    private readonly object _bufferLock = new();
    private readonly List<byte> _buffer = new();

    private const int HeaderSize = 8;

    public SocketState State => _state;

    public IObservable<Messages.SoulseekMessage> Messages => _messageSubject;
    public IObservable<SocketStateChanged> StateChanges => _stateSubject;

    public void Dispose()
    {
        Cleanup();
        _messageSubject.Dispose();
        _stateSubject.Dispose();
    }

    public async Task Connect(string host, int port, TimeSpan? timeout = null)
    {
        if (_state is SocketState.Connecting or SocketState.Connected)
            await Disconnect();

        SetState(SocketState.Connecting);

        try
        {
            var addresses = await Dns.GetHostAddressesAsync(host);
            if (addresses.Length == 0)
            {
                SetState(SocketState.Disconnected, SocketErrorType.DnsFailure, $"Could not resolve host: {host}");
                return;
            }

            var ipv4 = addresses.Where(a => a.AddressFamily == AddressFamily.InterNetwork).ToArray();
            var ipv6 = addresses.Where(a => a.AddressFamily == AddressFamily.InterNetworkV6).ToArray();
            var preferred = ipv4.Length > 0 ? ipv4 : (ipv6.Length > 0 ? ipv6 : addresses);

            _tcpClient = new TcpClient();
            _cts = new CancellationTokenSource();

            using var connectCts = new CancellationTokenSource(timeout ?? TimeSpan.FromSeconds(10));
            try
            {
                await _tcpClient.ConnectAsync(preferred[0], port, connectCts.Token);
            }
            catch (OperationCanceledException)
            {
                SetState(SocketState.Disconnected, SocketErrorType.Timeout, $"Connection timed out after {timeout ?? TimeSpan.FromSeconds(10)}");
                Cleanup();
                return;
            }

            _tcpClient.NoDelay = true;
            _stream = _tcpClient.GetStream();

            SetState(SocketState.Connected);

            _readLoopTask = Task.Run(() => ReadLoop(_cts.Token));
        }
        catch (SocketException e)
        {
            SetState(SocketState.Disconnected, ClassifySocketError(e), e.Message);
            Cleanup();
        }
        catch (Exception e)
        {
            SetState(SocketState.Disconnected, SocketErrorType.Unknown, e.Message);
            Cleanup();
        }
    }

    public void Accept(TcpClient tcpClient)
    {
        _tcpClient = tcpClient;
        _tcpClient.NoDelay = true;
        _stream = _tcpClient.GetStream();
        _cts = new CancellationTokenSource();

        SetState(SocketState.Connected);
        _readLoopTask = Task.Run(() => ReadLoop(_cts.Token));
    }

    public async Task Disconnect()
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = null;

        if (_readLoopTask != null)
        {
            try { await _readLoopTask; } catch { }
            _readLoopTask = null;
        }

        lock (_bufferLock) _buffer.Clear();

        if (_stream != null)
        {
            await _stream.DisposeAsync();
            _stream = null;
        }

        if (_tcpClient != null)
        {
            _tcpClient.Close();
            _tcpClient.Dispose();
            _tcpClient = null;
        }

        SetState(SocketState.Disconnected);
    }

    public void SendMessage(Messages.SoulseekMessage message)
    {
        SendRaw(message.Code, message.Payload);
    }

    public void SendRaw(int code, byte[] payload)
    {
        var stream = _stream;
        if (stream == null || _state != SocketState.Connected)
            throw new SocketManagerException("Not connected");

        var data = Messages.SoulseekMessage.Encode(code, payload);
        _writeLock.Wait();
        try
        {
            stream.Write(data, 0, data.Length);
        }
        finally
        {
            _writeLock.Release();
        }
    }

    private async Task ReadLoop(CancellationToken ct)
    {
        var buffer = new byte[8192];
        try
        {
            while (!ct.IsCancellationRequested)
            {
                var stream = _stream;
                if (stream == null) break;

                var bytesRead = await stream.ReadAsync(buffer, ct);
                if (bytesRead == 0) break;

                lock (_bufferLock)
                {
                    _buffer.AddRange(buffer.AsSpan(0, bytesRead));
                    TryParseMessages();
                }
            }
        }
        catch (OperationCanceledException) { }
        catch (ObjectDisposedException) { }
        catch
        {
            SetState(SocketState.Disconnected, SocketErrorType.ConnectionReset, "Connection lost");
        }
    }

    private void TryParseMessages()
    {
        while (true)
        {
            if (_buffer.Count < HeaderSize) break;

            var totalLength = BitConverter.ToUInt32(_buffer.Take(4).ToArray(), 0);
            var frameSize = 4 + (int)totalLength;

            if (_buffer.Count < frameSize) break;

            var frame = _buffer.Take(frameSize).ToArray();
            _buffer.RemoveRange(0, frameSize);

            try
            {
                var message = Messages.SoulseekMessage.Parse(frame);
                _messageSubject.OnNext(message);
            }
            catch
            {
                // Skip malformed frames
            }
        }
    }

    private void Cleanup()
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = null;

        _writeLock.Wait();
        try
        {
            _stream?.Close();
            _stream?.Dispose();
            _stream = null;

            _tcpClient?.Close();
            _tcpClient?.Dispose();
            _tcpClient = null;
        }
        finally
        {
            _writeLock.Release();
        }

        lock (_bufferLock) _buffer.Clear();
    }

    private void SetState(SocketState state, SocketErrorType errorType = SocketErrorType.None, string? message = null)
    {
        if (_state == state) return;
        _state = state;
        _stateSubject.OnNext(new SocketStateChanged(state, errorType, message));
    }

    private static SocketErrorType ClassifySocketError(SocketException e)
    {
        return e.SocketErrorCode switch
        {
            SocketError.ConnectionRefused => SocketErrorType.ConnectionRefused,
            SocketError.TimedOut => SocketErrorType.Timeout,
            SocketError.NetworkUnreachable => SocketErrorType.NetworkUnreachable,
            SocketError.ConnectionReset => SocketErrorType.ConnectionReset,
            _ => SocketErrorType.Unknown
        };
    }
}

public class SocketManagerException : Exception
{
    public SocketManagerException(string message) : base(message) { }
}