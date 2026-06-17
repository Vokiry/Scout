using System.Net;
using System.Net.Sockets;
using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Transfer;

namespace Soulseek.Protocol.Peer;

public class IncomingConnection : ITransferConnection
{
    private readonly SocketManager _socketManager;
    private string _username;

    public IncomingConnection(SocketManager socketManager, string username = "")
    {
        _socketManager = socketManager;
        _username = username;
    }

    public string Username => _username;

    public IObservable<SoulseekMessage> MessageStream => _socketManager.MessageStream;

    public void SendMessage(SoulseekMessage message) => _socketManager.SendMessage(message);
    public void SendRaw(int code, byte[] payload) => _socketManager.SendRaw(code, payload);

    public void Dispose() => _socketManager.Dispose();
}

public class PeerListener
{
    private TcpListener? _tcpListener;
    private readonly List<(IncomingConnection Connection, IDisposable Subscription)> _connections = [];
    private CancellationTokenSource? _cts;
    private Task? _listenTask;

    public UploadManager UploadManager { get; }

    public PeerListener(UploadManager uploadManager)
    {
        UploadManager = uploadManager;
    }

    public int Port { get; private set; }
    public bool IsListening => _tcpListener != null;
    public int ConnectionCount => _connections.Count;

    public Task Start(int port)
    {
        _tcpListener = new TcpListener(IPAddress.Any, port);
        _tcpListener.Start();
        Port = port;
        _cts = new CancellationTokenSource();

        _listenTask = Task.Run(() => AcceptLoop(_cts.Token));
        return Task.CompletedTask;
    }

    private async Task AcceptLoop(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                var tcpClient = await _tcpListener!.AcceptTcpClientAsync(ct);
                var socketManager = new SocketManager();
                socketManager.Accept(tcpClient);
                var connection = new IncomingConnection(socketManager);
                var sub = socketManager.MessageStream.Subscribe(message =>
                {
                    if (message.Code == PeerCode.TransferRequest)
                        HandleTransferRequest(message, connection);
                });
                _connections.Add((connection, sub));
            }
            catch (OperationCanceledException) { break; }
            catch { break; }
        }
    }

    private void HandleTransferRequest(SoulseekMessage message, IncomingConnection connection)
    {
        try
        {
            var buffer = new ReadBuffer(message.Payload);
            var direction = buffer.ReadInt32();
            var fileCode = buffer.ReadInt32();
            var filename = buffer.ReadString();
            var fileSize = buffer.ReadInt32();

            var request = new TransferRequest(direction, fileCode, filename, fileSize);
            _ = UploadManager.HandleTransferRequest(request, connection);
        }
        catch
        {
            // Skip malformed transfer requests
        }
    }

    public async Task Stop()
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = null;

        if (_tcpListener != null)
        {
            _tcpListener.Stop();
            _tcpListener = null;
        }

        if (_listenTask != null)
        {
            try { await _listenTask; } catch { }
            _listenTask = null;
        }

        foreach (var (conn, sub) in _connections)
        {
            sub.Dispose();
            conn.Dispose();
        }
        _connections.Clear();
    }

    public void Dispose()
    {
        _ = Stop();
    }
}