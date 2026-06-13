# AGENTS.md — Context for AI Coding Agents

This file documents the conventions, patterns, and structure of the Scout project so that AI agents can edit the codebase without breaking existing code or introducing inconsistencies.

## Project Identity

- **Name**: Scout (Soulseek for .NET)
- **Language**: C# 12 (.NET 8)
- **Solution file**: `Soulseek.sln`
- **Root namespace**: `Soulseek.Protocol` (all libraries), `Soulseek.Client` (console app), `Soulseek.Protocol.Tests` (tests)
- **Package ID**: `Soulseek.Protocol`

## Build System

- `dotnet build` / `dotnet test` (no `npm`, no `yarn`, no JavaScript tooling)
- `Directory.Build.props` at repo root applies to all projects:
  - `net8.0`, nullable enabled, treat warnings as errors
  - `CS1591` (missing XML doc) and `CA2007` (ConfigureAwait) suppressed
  - C# 12 implicit usings enabled
- `global.json` pins SDK to `8.0.x` (rollForward `latestFeature`)

Before committing code, always run:
```bash
dotnet restore && dotnet build --configuration Release && dotnet test --configuration Release
```

## Project Structure

```
Soulseek.Protocol/           # The only library — zero external dependencies
├── Connection/
│   ├── SocketManager.cs     # TCP transport (read loop, framing, write lock)
│   ├── ServerConnection.cs  # Server login, ping, disconnection relay
│   └── ReconnectionManager.cs  # Exponential backoff with jitter
├── Messages/
│   ├── Codes.cs             # ServerCode, PeerCode, DistantCode constants
│   ├── SoulseekMessage.cs   # Wire format: [length(4)][code(4)][payload]
│   ├── ReadBuffer.cs        # Binary deserialization (LE ints, strings)
│   ├── WriteBuffer.cs       # Binary serialization
│   └── Message.cs           # All message domain types (~25 classes)
├── Network/
│   └── DistributedNetwork.cs  # Parent/child relay for distributed search
├── Obfuscation/
│   └── Handshake.cs         # Pi-based XOR obfuscation handshake
├── Peer/
│   ├── PeerConnection.cs    # Outgoing peer connection wrapper
│   └── PeerListener.cs      # TCP peer listener server
├── Services/
│   ├── AuthService.cs       # Login/logout, connection state
│   ├── SearchService.cs     # File search (new + old format)
│   ├── ChatService.cs       # Private messaging
│   ├── UserService.cs       # User add, status, peer address
│   ├── BrowseService.cs     # Async browse with timeout + connection-close
│   ├── WishlistService.cs   # Wishlist search and management
│   └── RoomChatService.cs   # Room join/leave/message/list/tickers
├── Transfer/
│   ├── DownloadManager.cs   # Queue, retry, concurrent limits
│   └── UploadManager.cs     # Chunked send, deny callback
├── SoulseekClient.cs        # Main facade, wires everything together
└── Subject.cs               # Thread-safe IObservable<T> implementation
```

## Coding Conventions

### Namespace Layout
- Root namespace: `Soulseek.Protocol`
- Sub-namespaces: `Connection`, `Messages`, `Network`, `Obfuscation`, `Peer`, `Services`, `Transfer`
- Use **file-scoped namespaces** (C# 10+): `namespace Soulseek.Protocol.Connection;`
- `Subject<T>` lives in root `Soulseek.Protocol` so all sub-namespaces can reference it via parent-namespace resolution without additional `using` directives.

### Reactive Pattern
- All event/state exposures use `Subject<T>` (custom implementation, NOT `System.Reactive`).
- `Subject<T>` is thread-safe with snapshot iteration and dispose-guard.
- Never import `System.Reactive` or `System.Reactive.Linq` — there are no NuGet dependencies for `Soulseek.Protocol`.
- Services subscribe to `_server.Messages.Subscribe(...)` in `Init()` and store the `IDisposable` subscription handle.

### Interface Usage
- `ISocketTransport`: abstraction over `SocketManager` (used by `ServerConnection`, `DistributedNetwork`)
- `IServerTransport`: abstraction over `ServerConnection` (used by services)
- `ITransferConnection`: used by uploads (abstracts both `PeerConnection` and `IncomingConnection`)

### Error Handling
- Malformed messages are silently skipped (empty catch blocks with `// Skip malformed ...` comment).
- Connection errors flow through state-change observables (`SocketStateChanged`, `ServerConnectionState`).
- Browse timeout uses a `Timer` + `TaskCompletionSource`.
- Transfers use `TaskCompletionSource` with `responseReceived` flag to distinguish the 4-byte status from data chunks.
- Fire-and-forget tasks in event handlers are explicit: `_ = SomeMethodAsync();`

### Testing Conventions
- Framework: xUnit (no mocking libraries, no Moq/NSubstitute)
- Test files mirror source structure under `Soulseek.Protocol.Tests/`
- Test class naming: `{ComponentName}Tests`
- Test methods are `[Fact]` (no `[Theory]` used)
- No mocking — tests use real implementations with controlled inputs
- Test projects suppress `CA1707` (naming) and `CA2007` (await) warnings

### Thread Safety
- `Subject<T>` uses `lock` for observer list mutations, snapshot iteration for `OnNext`
- `SocketManager` uses `SemaphoreSlim(1,1)` for write serialization
- `BrowseService` uses `TaskCreationOptions.RunContinuationsAsynchronously` to prevent deadlock
- `ReconnectionManager` uses a `Timer` for delayed reconnect scheduling

### Important Design Decisions
1. **`SoulseekMessage` is `readonly record struct`** with `byte[] Payload`. Reference equality for `Payload` is acceptable because instances are never compared by value.
2. **No `ConfigureAwait(false)`** used anywhere — `CA2007` is suppressed in `Directory.Build.props`.
3. **`SocketManager.Accept()`** is used for incoming connections (assumes `TcpClient` is already connected) instead of `Connect()`.
4. **`BrowseObserver`** (custom `IObserver<SoulseekMessage>`) handles `OnCompleted`/`OnError` from connection close to unblock the browse task, rather than relying solely on timeout.
5. **Transfer detection** uses a `responseReceived` bool flag to separate the initial 4-byte status from subsequent file data chunks.
6. **`PeerListener`** routes incoming `TransferRequest` messages to `UploadManager.HandleTransferRequest` fire-and-forget.

## What NOT to Do

- Do **NOT** add NuGet packages to `Soulseek.Protocol.csproj` — it must remain zero-dependency.
- Do **NOT** use `System.Reactive` types (`Observable`, `Subject` from Rx.NET) — use the custom `Subject<T>`.
- Do **NOT** use `INotifyPropertyChanged`, `event` delegates, or `IProgress<T>` — use `IObservable<T>`.
- Do **NOT** add mocking frameworks to the test project.
- Do **NOT** suppress CA2007 or CS1591 in individual files — they are already suppressed globally.
- Do **NOT** remove the `// Skip malformed messages` catch blocks — they are intentional protocol hardening.

## Git Workflow

- Branches should target `main`
- Commit messages should be concise, imperative mood, matching repo style
- No `--force` push, no interactive rebase
- Always inspect `git status` and `git diff` before committing
