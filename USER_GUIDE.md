# User Guide — Scout Soulseek Client

## Prerequisites

- .NET 8.0 SDK ([download](https://dotnet.microsoft.com/download/dotnet/8.0))
- A Soulseek account (free registration at [slsknet.org](https://www.slsknet.org))

## Building

```bash
# Clone and enter
git clone <url> scout
cd scout

# Restore dependencies
dotnet restore

# Build all projects (Release)
dotnet build --configuration Release

# Run tests
dotnet test --configuration Release

# Build the NuGet package
dotnet pack --configuration Release
```

## Running the Console Client

```bash
dotnet run --project Soulseek.Client -- <username> <password>
```

### Available Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/search <query>` | `/search depeche mode violation` | Search for files matching the query |
| `/pm <user> <msg>` | `/pm john_doe hello there` | Send a private message |
| `/room <name>` | `/room music` | Join a chat room |
| `/room <name> <msg>` | `/room music check this track` | Send a message to a chat room |
| `/wish <phrase>` | `/wish moby 1999` | Add a wishlist item |
| `/help` | `/help` | Show available commands |
| `/quit` | `/quit` | Disconnect and exit |

### Output

The client logs all events to the console:
- Connection state changes (connecting, connected, reconnecting, disconnected)
- Incoming search results (username + file count)
- Private messages formatted as `[PM] user: message`
- Room messages formatted as `[room] user: message`
- Download progress (percentage + speed)

## Using the Library

### Add to Your Project

```bash
dotnet add reference <path-to-scout>/Soulseek.Protocol/Soulseek.Protocol.csproj
```

Or use the NuGet package:
```xml
<PackageReference Include="Soulseek.Protocol" Version="0.1.0" />
```

### Basic Usage

```csharp
using Soulseek.Protocol;
using Soulseek.Protocol.Messages;

var client = new SoulseekClient();
client.Init();

// Subscribe to events
client.ConnectionState.Subscribe(state =>
    Console.WriteLine($"State: {state}"));

client.SearchResults.Subscribe(result =>
{
    Console.WriteLine($"Results from {result.Username}:");
    foreach (var file in result.Files)
        Console.WriteLine($"  {file.Filename} ({file.Size} bytes)");
});

client.PrivateMessages.Subscribe(pm =>
    Console.WriteLine($"[PM] {pm.Username}: {pm.Message}"));

client.DownloadProgress.Subscribe(progress =>
{
    foreach (var (key, p) in progress)
        if (p.State == DownloadState.Downloading)
            Console.WriteLine($"{p.Filename}: {p.Percentage * 100:F1}%");
});

// Connect
await client.Connect("your_username", "your_password");

// Search
var ticket = client.Search("depeche mode");

// Browse a user's shares
var shares = await client.BrowseUser("some_user", ip, port, "");
foreach (var folder in shares.Folders)
{
    Console.WriteLine($"{folder.Path}: {folder.Files.Count} files");
    foreach (var file in folder.Files)
        Console.WriteLine($"  {file.Filename}");
}

// Download a file
client.EnqueueDownload("artist/album/track.mp3", 12345678, "some_user", 42);

// Send a message
client.SendPrivateMessage("some_user", "Thanks for sharing!");

// Join a room
client.JoinRoom("music");

// Wishlist
client.AddWishlistItem("my favorite album");

// Clean up
client.Dispose();
```

### Customizing the Server

```csharp
// Before calling Connect()
client.SetServer("custom-server.com", 2244);
```

### Setting Listen Port (for incoming uploads)

```csharp
await client.StartListening(50000);
// Now other peers can connect to you for uploads
```

## Configuration Reference

| Setting | Default | Location | Description |
|---------|---------|----------|-------------|
| Server host | `server.slsknet.org` | `ServerConnection.cs:47` | Soulseek server address |
| Server port | `2244` | `ServerConnection.cs:48` | Soulseek server port |
| Login version | 17/1/0 | `Message.cs:23` | Protocol version identifiers |
| Connection timeout | 10s | `SocketManager.cs:92` | TCP connect timeout |
| Browse timeout | 30s | `BrowseService.cs:13` | Max wait for browse response |
| Reconnect base delay | 1s | `ReconnectionManager.cs:5` | Initial reconnect delay |
| Reconnect max delay | 60s | `ReconnectionManager.cs:6` | Maximum reconnect delay |
| Reconnect multiplier | 2.0 | `ReconnectionManager.cs:7` | Exponential backoff factor |
| Reconnect jitter | ±500ms | `ReconnectionManager.cs:9` | Random jitter range |
| Max concurrent downloads | 3 | `DownloadManager.cs:86` | Simultaneous downloads |
| Max download retries | 3 | `DownloadManager.cs:86` | Retry attempts on failure |
| Upload chunk size | 1 MiB | `UploadManager.cs:58` | File chunk size for uploads |
| Max concurrent uploads | 3 | `UploadManager.cs:60` | Simultaneous uploads |
| Max child branches | 10 | `DistributedNetwork.cs:34` | Distributed network children |

## Troubleshooting

| Symptom | Likely Cause | Solution |
|---------|-------------|----------|
| `Connection timed out` | Server unreachable or firewall | Check `server.slsknet.org:2244` is reachable, or use `SetServer()` |
| `Login rejected` | Wrong credentials | Verify username and password |
| `Browse timed out` | Peer offline or slow | The peer may be behind a firewall; retry later |
| `Transfer denied` | Upload queue full | The remote user is busy; retry later |
| `No search results` | Nothing matches | Try broader terms or check connectivity |
| Connection drops repeatedly | Unstable network | Reconnection manager will auto-retry |

## Architecture Decisions

- **Zero dependencies**: The protocol library is pure .NET 8 with no external packages, making it suitable for environments with strict dependency policies.
- **Reactive API**: All events use `IObservable<T>` — integrate with `Subscribe()` or bridge to `System.Reactive` if you need LINQ-style operators.
- **Async throughout**: All I/O operations are async/await based; no blocking calls.
- **Thread safety**: `Subject<T>` uses snapshot iteration and locks; `SocketManager` serializes writes with `SemaphoreSlim`.

## Known Limitations

- Place-in-queue polling is not yet implemented
- No GUI client — only console-mode interaction
- Uploads require an opened port (NAT/firewall may prevent incoming connections)
- Distributed network integration is code-complete but not end-to-end tested against live servers
