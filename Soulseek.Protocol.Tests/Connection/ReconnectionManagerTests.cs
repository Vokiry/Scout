using Soulseek.Protocol.Connection;

namespace Soulseek.Protocol.Tests.Connection;

public class ReconnectionManagerTests
{
    [Fact]
    public void CalculateDelay_FirstAttempt_IsZero()
    {
        var socketMock = new MockSocketTransport();
        var rm = new ReconnectionManager(socketMock);
        rm.Start("localhost", 2244);

        var state = rm.State;
        Assert.Equal(0, state.Attempt);
    }

    [Fact]
    public void Config_DefaultValues_AreSensible()
    {
        var config = new ReconnectionConfig();
        Assert.Equal(TimeSpan.FromSeconds(1), config.BaseDelay);
        Assert.Equal(TimeSpan.FromSeconds(60), config.MaxDelay);
        Assert.Equal(2.0, config.Multiplier);
        Assert.Equal(-1, config.MaxAttempts);
        Assert.Equal(1000, config.JitterMs);
    }

    [Fact]
    public void Stop_StopsReconnection()
    {
        var socketMock = new MockSocketTransport();
        var rm = new ReconnectionManager(socketMock);
        rm.Start("host", 1234);
        rm.Stop();
        Assert.False(rm.State.IsRunning);
    }

    [Fact]
    public void Reset_ClearsAttempts()
    {
        var socketMock = new MockSocketTransport();
        var rm = new ReconnectionManager(socketMock, new ReconnectionConfig { MaxAttempts = 3 });

        rm.Start("host", 1234);
        // Simulate multiple disconnections to trigger reconnect attempts
        for (int i = 0; i < 2; i++)
        {
            socketMock.SimulateDisconnect("test");
        }
        Assert.True(rm.State.Attempt > 0);

        rm.Reset();
        Assert.Equal(0, rm.State.Attempt);
    }

    [Fact]
    public void ConnectedState_ResetsReconnection()
    {
        var socketMock = new MockSocketTransport();
        var rm = new ReconnectionManager(socketMock);
        rm.Start("host", 1234);

        socketMock.SimulateDisconnect("first");
        Assert.True(rm.State.Attempt >= 1);

        socketMock.SimulateConnect();
        Assert.False(rm.State.IsRunning);
        Assert.Equal(0, rm.State.Attempt);
    }
}

internal class MockSocketTransport : ISocketTransport
{
    private readonly Subject<Messages.SoulseekMessage> _messages = new();
    private readonly Subject<SocketStateChanged> _stateChanges = new();
    private SocketState _state = SocketState.Disconnected;

    public SocketState State => _state;

    public IObservable<Messages.SoulseekMessage> Messages => _messages;
    public IObservable<SocketStateChanged> StateChanges => _stateChanges;

    public Task Connect(string host, int port, TimeSpan? timeout = null)
    {
        _state = SocketState.Connected;
        return Task.CompletedTask;
    }

    public Task Disconnect()
    {
        _state = SocketState.Disconnected;
        return Task.CompletedTask;
    }

    public void SendMessage(Messages.SoulseekMessage message) { }
    public void SendRaw(int code, byte[] payload) { }

    public void SimulateConnect()
    {
        _state = SocketState.Connected;
        _stateChanges.OnNext(new SocketStateChanged(SocketState.Connected));
    }

    public void SimulateDisconnect(string? error = null)
    {
        _state = SocketState.Disconnected;
        _stateChanges.OnNext(new SocketStateChanged(SocketState.Disconnected, SocketErrorType.ConnectionReset, error));
    }

    public void Dispose()
    {
        _messages.Dispose();
        _stateChanges.Dispose();
    }
}