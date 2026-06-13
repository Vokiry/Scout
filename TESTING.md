# Compilation & Manual Testing Guide

## Compile & Run on Phone (Android via Termux)

### Option A — Self-contained publish from PC (recommended)

```bash
# On PC, from repo root:
dotnet publish Soulseek.Client \
  -r linux-arm64 \
  --self-contained \
  -c Release \
  -o ~/Desktop/scout-arm64
```

Copy the whole `scout-arm64` folder to your phone via ADB, USB, or cloud:

```bash
# Example via ADB:
adb push ~/Desktop/scout-arm64 /data/local/tmp/scout
```

On phone in Termux:

```bash
# Make executable (if needed)
chmod +x /data/local/tmp/scout/Soulseek.Client

# Run
/data/local/tmp/scout/Soulseek.Client myuser mypass
```

### Option B — Run dotnet directly in Termux (slower, needs ~700MB)

```bash
# In Termux:
pkg update && pkg install proot-distro
proot-distro install ubuntu
proot-distro login ubuntu

# Inside Ubuntu:
apt update && apt install -y wget
wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 8.0
export PATH=$HOME/.dotnet:$PATH
echo 'export PATH=$HOME/.dotnet:$PATH' >> ~/.bashrc

# Exit Ubuntu, then enter again with networking:
proot-distro login ubuntu --bind /proc:/proc --bind /sys:/sys

# Now clone & run:
git clone <repo-url> scout
cd scout
dotnet restore
dotnet run --project Soulseek.Client -- myuser mypass
```

---

## Manual Test Cases

Run each step in order. The client must remain connected between tests.

### 1. Connectivity & Auth

| # | Step | Expected Result |
|---|------|----------------|
| 1.1 | `dotnet run --project Soulseek.Client -- invalidUser invalidPass` | See: `Connection state: Connecting`, then `Connection state: Disconnected` or `Authenticated: False`. Should not crash. |
| 1.2 | Run with valid credentials | See `Connection state: Connecting` → `Connected` → `Authenticated: True`. Prompt appears. |
| 1.3 | Wait 30 seconds without typing | Should stay connected (ping/pong keepalive). No "Disconnected" message. |
| 1.4 | `/quit` | App exits cleanly. No unhandled exceptions. |

### 2. Search

| # | Step | Expected Result |
|---|------|----------------|
| 2.1 | `/search depeche mode violation` | See: `Search submitted with ticket 1: depeche mode violation`. Within 10-20s: results start appearing. |
| 2.2 | Check result fields | Each result prints `{username}: {count} files`. Files should have name, size. |
| 2.3 | `/search test 123` | Ticket number increments (2). Results appear. |
| 2.4 | `/search 日本語` | Unicode search works. Results appear. |

### 3. Private Messaging

| # | Step | Expected Result |
|---|------|----------------|
| 3.1 | `/pm` (no args) | See: `Usage: /pm <username> <message>` |
| 3.2 | `/pm someKnownUser Hello from Scout!` | Message sent. If user online, no error. |
| 3.3 | Ask a friend to PM you | Within a few seconds: `[PM] username: message` appears. |

### 4. Room Chat

| # | Step | Expected Result |
|---|------|----------------|
| 4.1 | `/room` (no args) | See: `Usage: /room <roomname> [message]` |
| 4.2 | `/room test` | Join room "test". No error. |
| 4.3 | `/room music hello everyone` | Sends message to room "music" (auto-joins). |
| 4.4 | Wait for other users' messages | See: `[roomname] username: message` |

### 5. Wishlist

| # | Step | Expected Result |
|---|------|----------------|
| 5.1 | `/wish` (no args) | See: `Usage: /wish <phrase>` |
| 5.2 | `/wish moby` | No immediate feedback (wishlist is server-side). |
| 5.3 | Wait 5-10 minutes | If wishlist results come in: `WishlistReply` data appears. |
| 5.4 | Restart client and `/wish moby` again | Should not error (server remembers). |

### 6. Reconnection

| # | Step | Expected Result |
|---|------|----------------|
| 6.1 | While connected, enable airplane mode | See: `Connection state: Reconnecting` |
| 6.2 | Wait 5-10 seconds, disable airplane mode | See: `Connection state: Connected` `Authenticated: True`. |
| 6.3 | Run `/search test` after reconnect | Search works again. |

### 7. Peer Browse (requires a user with shares)

| # | Step | Expected Result |
|---|------|----------------|
| 7.1 | This feature requires programmatic API access. Use a small test script (see below). |

**Test script** (run as separate console app or `dotnet-script`):

```csharp
// Save as TestBrowse.csproj + TestBrowse.cs in a temp folder
// file TestBrowse.csproj:
// <Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><OutputType>Exe</OutputType>
// <TargetFramework>net8.0</TargetFramework></PropertyGroup>
// <ItemGroup><ProjectReference Include="..\Soulseek.Protocol\Soulseek.Protocol.csproj" /></ItemGroup></Project>

using Soulseek.Protocol;
using Soulseek.Protocol.Messages;
using Soulseek.Protocol.Connection;

var client = new SoulseekClient();
client.Init();
client.ConnectionState.Subscribe(s => Console.WriteLine($"State: {s}"));

await client.Connect("youruser", "yourpass");
Console.WriteLine("Connected");

// Pick a user from search results that has files
client.SearchResults.Subscribe(async result =>
{
    Console.WriteLine($"Got {result.Files.Count} files from {result.Username}");
    if (result.Files.Count > 0)
    {
        try
        {
            Console.WriteLine($"Browsing {result.Username}...");
            // You need the user's IP:port — get from UserService or hardcode
            // client.AddUser(result.Username);  // triggers status/address response
            // Then: await client.BrowseUser(result.Username, ip, port, "");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Browse failed: {ex.Message}");
        }
    }
});

client.Search("test 123");
Console.ReadLine();
```

### 8. Edge Cases

| # | Step | Expected Result |
|---|------|----------------|
| 8.1 | Send empty string `/search` | Writes nothing (parts.Length >= 2 check handles it). |
| 8.2 | `/search` with 300+ chars | Should work (protocol has no query length limit). |
| 8.3 | `/pm user` (no message) | Shows usage warning. |
| 8.4 | Paste binary garbage into prompt | Ignored (unknown command warning). |
| 8.5 | Ctrl+C during search | Client exits cleanly (CancelKeyPress handler). |

### Pass Criteria

All tests in sections 1-4 pass fully. Sections 5 (wishlist) and 6 (reconnection) pass with expected behavior even if slow. Section 7 is optional (depends on peer availability). Section 8 must not crash the client.
