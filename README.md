# Scout — Soulseek for .NET

A production-ready, zero-dependency C# implementation of the Soulseek peer-to-peer file sharing protocol (`.NET 8`).

```
Soulseek.sln
├── Soulseek.Protocol/          # Core protocol library (net8.0, pure .NET)
├── Soulseek.Client/            # Console host with DI and logging
├── Soulseek.Maui/              # Android MAUI app (net8.0-android)
└── Soulseek.Protocol.Tests/    # xUnit tests (146+ methods)
```

## Quick Start

```bash
dotnet restore
dotnet build --configuration Release
dotnet test --configuration Release
dotnet run --project Soulseek.Client -- <username> <password>
```

## Architecture

The library is built on a **reactive foundation** — all state changes and events are exposed as `IObservable<T>` via `Subject<T>`, mirroring the Dart `Stream` pattern from the original Flutter implementation.

### Layer Overview

```
┌─────────────────────────────────────────────────┐
│                  SoulseekClient                  │  Facade
├─────────────────────────────────────────────────┤
│ Auth  Search  Chat  Users  Browse  Wishlist  Room│  Services
├─────────────────────────────────────────────────┤
│ ServerConnection   PeerConnection  PeerListener  │  Connection
│ DistributedNetwork                               │
├─────────────────────────────────────────────────┤
│ SocketManager (TCP framing)                      │  Transport
├─────────────────────────────────────────────────┤
│ SoulseekMessage  ReadBuffer  WriteBuffer         │  Protocol
└─────────────────────────────────────────────────┘
```

### Transport — `SocketManager`

- TCP client with async read-loop, message framing (8-byte header), and write-lock via `SemaphoreSlim`
- DNS resolution with IPv4 preference
- State machine: `Disconnected → Connecting → Connected`
- Handles connection refused, DNS failure, timeout, reset
- Accepts pre-connected `TcpClient` for incoming peer connections

### Server Connection — `ServerConnection`

- Login flow, ping/pong keep-alive, graceful shutdown detection
- `ReconnectionManager` with exponential backoff + jitter
- Configurable base delay (1s), max delay (60s), multiplier (2x), max attempts (-1 = infinite)

### Message Protocol

Every message on the wire has this frame:

```
┌──────────────────────────────────────┐
│  Length (uint32 LE, 4 bytes)         │  total frame - 4
├──────────────────────────────────────┤
│  Code   (uint32 LE, 4 bytes)         │  ServerCode / PeerCode
├──────────────────────────────────────┤
│  Payload (Length - 4 bytes)          │  message-specific data
└──────────────────────────────────────┘
```

All integers are **little-endian**. Strings are length-prefixed (uint32 LE) UTF-8.

### Services

| Service | Listenable | Description |
|---------|-----------|-------------|
| `AuthService` | `ConnectionState`, `ConnectionInfo` | Server login/logout |
| `SearchService` | `SearchResults` | File search (new + old format) |
| `ChatService` | `PrivateMessages` | Private messaging |
| `UserService` | `UserStatus` | User lookup and status |
| `BrowseService` | — | Browse peer shares (async request/response with timeout) |
| `WishlistService` | `WishlistResults` | Wishlist search and management |
| `RoomChatService` | `RoomMessages`, `UserJoined`, `UserLeft`, `RoomList` | Room chat |

### Peer-to-Peer

- `PeerConnection` wraps a `SocketManager` with username/ip/port metadata
- `PeerListener` accepts incoming TCP connections, routes `TransferRequest` to `UploadManager`
- `PeerConnectionType.Incoming` / `PeerConnectionType.Outgoing`

### Transfers

- `DownloadManager`: queue-based, configurable max concurrent (3) and max retries (3), supports pause/resume/cancel/retry
- `UploadManager`: chunked (1MiB) file sending, handles deny callback
- Transfer flow: `TransferRequest` (135) → `TransferResponse` (136) with status code (0 = ok, 1 = denied, 2 = not found)

### Distributed Network

- Parent/child relay via `DistributedNetwork`
- Search propagation through the distributed tree
- Configurable max child branches (10)
- Obfuscation handshake using Pi-based XOR key derivation

### Obfuscation

The `ObfuscationHandshake` class implements:
- Token exchange (our token XOR peer token)
- Key derivation from Pi digits
- XOR encode/decode (symmetric)

## API Surface

### `SoulseekClient` — Main facade

```csharp
var client = new SoulseekClient();
client.Init();
await client.Connect(username, password);

// Listen
client.SearchResults.Subscribe(result => { /* ... */ });
client.PrivateMessages.Subscribe(pm => { /* ... */ });

// Search
int ticket = client.Search("depeche mode");

// Browse
var shares = await client.BrowseUser(username, ip, port);

// Download
client.EnqueueDownload("file.mp3", 12345678, "user", 42);

// Disconnect
client.Dispose();
```

### Observable Endpoints

| Property | Type | Description |
|----------|------|-------------|
| `ConnectionState` | `IObservable<ServerConnectionState>` | Disconnected / Connecting / Connected / Reconnecting |
| `SearchResults` | `IObservable<SearchResult>` | File search results |
| `PrivateMessages` | `IObservable<PrivateMessage>` | Incoming private messages |
| `UserStatus` | `IObservable<UserStatusMessage>` | User online/away status |
| `DownloadProgress` | `IObservable<Dictionary<string, DownloadProgress>>` | All active downloads |
| `WishlistResults` | `IObservable<WishlistReply>` | Wishlist search results |
| `RoomMessages` | `IObservable<RoomMessageData>` | Room chat messages |
| `RoomUserJoined` | `IObservable<UserJoinedRoom>` | Users joining rooms |
| `RoomUserLeft` | `IObservable<UserLeftRoom>` | Users leaving rooms |
| `RoomList` | `IObservable<RoomList>` | Available chat rooms |
| `ConnectionInfo` | `IObservable<ConnectionInfo>` | Auth result, IP, port, obfuscation status |

## Dependencies

- **Soulseek.Protocol**: Zero external dependencies (`System.*`, `Microsoft.*` only)
- **Soulseek.Client**: `Microsoft.Extensions.Hosting`, `Microsoft.Extensions.Logging.Console`
- **Soulseek.Protocol.Tests**: `xunit`, `Microsoft.NET.Test.Sdk`, `coverlet.collector`
- **Soulseek.Maui**: `Microsoft.Maui.Controls`, `CommunityToolkit.Mvvm`

## Configuration

- Default server: `server.slsknet.org:2244` (configurable via `SetServer`)
- Connection timeout: 10 seconds
- Browse timeout: 30 seconds
- Reconnection: base 1s, max 60s, multiplier 2x, jitter ±500ms
- Download retries: 3 max

## Project Settings

- `Directory.Build.props`: `net8.0`, nullable enabled, treat warnings as errors, C# 12
- `global.json`: SDK 8.0.x, rollForward `latestFeature`
- `.github/workflows/ci.yml`: restore → build Release → test (Linux) + publish MAUI APK (Windows)

## Missing Features (Not Yet Implemented)

- Place-in-queue polling (`PlaceInQueue` response)
- Privileges checking
- User info (avatar, description)
- Folder browsing with subdirectory support
- Room tickers display
- Private rooms
- Interest management (likes/dislikes)

## License

Copyright (c) 2024 vokiry
