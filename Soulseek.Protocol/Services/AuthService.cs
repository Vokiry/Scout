using Soulseek.Protocol.Connection;

namespace Soulseek.Protocol.Services;

public class AuthService
{
    private readonly IServerTransport _server;

    public AuthService(IServerTransport server)
    {
        _server = server;
    }

    public IObservable<ServerConnectionState> ConnectionState => _server.StateChanges;
    public IObservable<ConnectionInfo> ConnectionInfo => _server.ConnectionInfo;
    public ServerConnectionState State => _server.State;
    public bool Authenticated => _server.Authenticated;
    public string? Username => _server.Username;

    public void Init() => _server.Init();

    public Task Connect(string username, string password) => _server.Connect(username, password);

    public Task Disconnect() => _server.Disconnect();

    public void Dispose() => _server.Dispose();
}