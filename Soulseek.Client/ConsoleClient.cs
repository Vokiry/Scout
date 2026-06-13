using Microsoft.Extensions.Logging;
using Soulseek.Protocol;
using Soulseek.Protocol.Connection;
using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Services;
using Soulseek.Protocol.Transfer;

namespace Soulseek.Client;

class ConsoleClient
{
    private readonly ILogger<ConsoleClient> _logger;
    private readonly SoulseekClient _client;
    private bool _running = true;

    public ConsoleClient(ILogger<ConsoleClient> logger)
    {
        _logger = logger;
        _client = new SoulseekClient();
    }

    public async Task RunAsync(string username, string password)
    {
        Console.CancelKeyPress += (_, e) =>
        {
            e.Cancel = true;
            _running = false;
        };

        SetupSubscriptions();

        _logger.LogInformation("Connecting to Soulseek server...");
        _client.Init();
        await _client.Connect(username, password);

        _logger.LogInformation("Connected! Authenticated: {Auth}", _client.Authenticated);

        while (_running)
        {
            var input = Console.ReadLine();
            if (input == null || input == "/quit") break;

            await HandleCommand(input);
        }

        _client.Dispose();
    }

    private void SetupSubscriptions()
    {
        _client.ConnectionState.Subscribe(state =>
        {
            _logger.LogInformation("Connection state: {State}", state);
        });

        _client.SearchResults.Subscribe(result =>
        {
            _logger.LogInformation("Search results from {User}: {Count} files",
                result.Username, result.Files.Count);
        });

        _client.PrivateMessages.Subscribe(pm =>
        {
            _logger.LogInformation("[PM] {User}: {Message}", pm.Username, pm.Message);
        });

        _client.RoomMessages.Subscribe(msg =>
        {
            _logger.LogInformation("[{Room}] {User}: {Message}", msg.RoomName, msg.Username, msg.Message);
        });

        _client.DownloadProgress.Subscribe(progress =>
        {
            foreach (var (key, value) in progress)
            {
                if (value.State == DownloadState.Downloading)
                {
                    _logger.LogInformation("Downloading {File}: {Pct:F1}% ({Speed} KB/s)",
                        value.Filename, value.Percentage * 100,
                        value.Speed.HasValue ? value.Speed / 1024 : 0);
                }
            }
        });
    }

    private Task HandleCommand(string input)
    {
        var parts = input.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return Task.CompletedTask;

        switch (parts[0].ToLower())
        {
            case "/search":
                var query = string.Join(' ', parts[1..]);
                var ticket = _client.Search(query);
                _logger.LogInformation("Search submitted with ticket {Ticket}: {Query}", ticket, query);
                break;

            case "/pm":
                if (parts.Length < 3)
                    _logger.LogWarning("Usage: /pm <username> <message>");
                else
                    _client.SendPrivateMessage(parts[1], string.Join(' ', parts[2..]));
                break;

            case "/room":
                if (parts.Length < 2)
                    _logger.LogWarning("Usage: /room <roomname> [message]");
                else if (parts.Length == 2)
                    _client.JoinRoom(parts[1]);
                else
                    _client.SendRoomMessage(parts[1], string.Join(' ', parts[2..]));
                break;

            case "/wish":
                if (parts.Length < 2)
                    _logger.LogWarning("Usage: /wish <phrase>");
                else
                    _client.AddWishlistItem(string.Join(' ', parts[1..]));
                break;

            case "/help":
                Console.WriteLine("""
                    Available commands:
                      /search <query>        - Search for files
                      /pm <user> <message>   - Send private message
                      /room <name> [msg]     - Join or message a room
                      /wish <phrase>         - Add wishlist item
                      /quit                  - Exit
                    """);
                break;

            default:
                _logger.LogWarning("Unknown command: {Cmd}. Type /help for commands.", parts[0]);
                break;
        }
        return Task.CompletedTask;
    }
}