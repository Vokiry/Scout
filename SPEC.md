# Soulseek Protocol Specification (as Implemented)

## Wire Format

Every message on the wire follows this framing:

```
┌─────────────────────────────────────────────────────────┐
│ Byte 0-3    │ Length (uint32, little-endian)             │
│             │ Total frame size minus 4 (i.e. code +      │
│             │ payload length)                             │
├─────────────────────────────────────────────────────────┤
│ Byte 4-7    │ Code (uint32, little-endian)              │
│             │ ServerCode, PeerCode, or DistantCode       │
├─────────────────────────────────────────────────────────┤
│ Byte 8+     │ Payload (Length - 4 bytes)                 │
│             │ Message-type-specific fields               │
└─────────────────────────────────────────────────────────┘
```

**Rules:**
- All multi-byte integers are **little-endian**
- Strings are length-prefixed: `uint32 length` followed by `length` bytes of UTF-8
- `uint32` is always 4 bytes; `uint64` is always 8 bytes
- The minimum frame is 8 bytes (length=4, code, empty payload)
- Maximum payload length is not bounded by this implementation

## Message Codes

### Server Codes (client ↔ server)

| Code | Name | Direction | Fields |
|------|------|-----------|--------|
| 1 | `Login` | C→S | username(string), password(string), minorVersion(int32), majorVersion(int32), buildVersion(int32) |
| 2 | `SetListenPort` | C→S | port(int32) |
| 3 | `GetPeerAddress` | C→S | username(string) |
| 5 | `AddUser` | C→S | username(string) |
| 26 | `SearchRequest` | C→S | ticket(int32), query(string) |
| 28 | `SearchResponse` | S→C | *(see Search Response below)* |
| 34 | `UserExists` | C→S | username(string) |
| 35 | `UserExistsResponse` | S→C | username(string), exists(int32) |
| 36 | `GetStatus` | C→S | username(string) |
| 37 | `StatusResponse` | S→C | username(string), status(int32) |
| 40 | `Ping` | S→C | *(empty payload)* |
| 41 | `Pong` | C→S | *(empty payload)* |
| 43 | `JoinRoom` | C→S | room(string) |
| 44 | `LeaveRoom` | C→S | room(string) |
| 45 | `UserJoinedRoom` | S→C | room(string), username(string), [slots(int32), speed(int32), files(int32), dirs(int32)] |
| 46 | `UserLeftRoom` | S→C | room(string), username(string) |
| 47 | `RoomMessage` | S→C / C→S | room(string), username(string), message(string) |
| 48 | `RoomList` | S→C / C→S | count(int32), {name(string), userCount(int32)}[] |
| 51 | `PrivateMessage` | S→C / C→S | username(string), message(string), timestamp(int32) |
| 55 | `ServerShuttingDown` | S→C | message(string) |
| 58 | `CheckDownloadQueue` | C→S | count(int32), {username(string)}[] |
| 60 | `UserSearchResponse` | S→C | *(same format as SearchResponse)* |
| 67 | `Wishes` | C→S | ticket(int32), query(string) |
| 68 | `WishReply` | S→C | *(same format as SearchResponse)* |
| 69 | `WishlistInclusion` | C→S | add(int32: 0|1), phrase(string) |
| 131 | `FolderContents` | C→S | token(int32), directory(string) |
| 132 | `FolderContentsReply` | S→C | *(server-side directory listing)* |
| 150 | `RoomTickerSet` | C→S | room(string), ticker(string) |
| 151 | `RoomTickerRemove` | C→S | room(string) |
| 154 | `UserStats` | C→S | username(string) |
| 162 | `AcceptChildren` | C→S | accept(int32: 0|1) |
| 206 | `LoginResponse` | S→C | success(int32), ip(int32), port(int32), [obfuscated(int32)] |
| 211 | `SetListenPort2` | C→S | port(int32) |

### Peer Codes (peer ↔ peer)

| Code | Name | Direction | Fields |
|------|------|-----------|--------|
| 131 | `FolderContents` | C→R | directory(string) |
| 132 | `FolderContentsReply` | R→C | folderCount(int32), {path(string), fileCount(int32), files[]} |
| 133 | `UserInfo` | C→R | *(empty payload)* |
| 134 | `UserInfoReply` | R→C | *(user info body)* |
| 135 | `TransferRequest` | C→R | direction(int32: 0=dl, 1=ul), fileCode(int32), filename(string), fileSize(int32) |
| 136 | `TransferResponse` | R→C | status(int32: 0=ok, 1=denied, 2=not found) then raw file data |
| 147 | `SearchResponse` | R→C | *(shared search result format)* |

### Distant Codes (distributed network relay)

| Code | Name | Direction | Fields |
|------|------|-----------|--------|
| 3 | `FileSearch` | Parent→Child | username(string), ticket(int32), query(string) |
| 4 | `FileSearchReply` | Child→Parent | username(string), ticket(int32), freeSlots(int32), speed(int32), queueLen(int32), fileCount(int32), files[] |

## Message Body Formats

### Login Response (Code 206)

```
success(int32)      — 1 = accepted, 0 = rejected
ip(int32)           — server-assigned IP (4-byte packed)
port(int32)         — server-assigned port
[obfuscated(int32)] — 1 = obfuscation supported (optional field)
```

### Search Response (Code 28 / 60 / 68)

**New format (tried first):**
```
username(string)
ticket(int32)
totalFileCount(int32)
freeUploadSlots(int32)
uploadSpeed(int32)
queueLength(int32)
fileCount(int32)
files[]:
  code(int32)
  filename(string)
  size(int32)
  extension(string)
  attributeCount(int32)
  attributes[]:
    type(int32), value(int32)  — types: 0=bitrate, 1=duration, 2=samplerate, 3=bitrate(vbr)
```

**Old format (fallback on parse failure):**
```
username(string)
ticket(int32)
fileCount(int32)
files[]:  (same as above but size is int32)
```

### Transfer Request (Code 135)

```
direction(int32)    — 0 = download (remote→us), 1 = upload (us→remote)
fileCode(int32)     — per-user file identifier from search results
filename(string)    — full path of the file
fileSize(int32)     — size in bytes
```

### Transfer Response (Code 136)

The first message has a 4-byte status code:
```
status(int32)       — 0 = allowed, 1 = denied (queued), 2 = file not found
```

Subsequent messages contain raw file data chunks (variable size, up to 1 MiB).

### Folder Contents (Code 131 request / 132 reply)

**Request:**
```
directory(string)   — empty string = browse all, otherwise subdirectory
```

**Reply:**
```
folderCount(int32)
folders[]:
  path(string)
  fileCount(int32)
  files[]:
    code(int32)
    filename(string)
    size(uint64)
    extension(string)
    attributeCount(int32)
    attributes[]:
      type(int32), value(int32)
```

### Distributed Search (Code 3 / 4)

**Parent→Child (Code 3):**
```
username(string)    — originating searcher
ticket(int32)       — search ticket
query(string)       — raw query text
```

**Child→Parent (Code 4):**
```
username(string)
ticket(int32)
freeUploadSlots(int32)
uploadSpeed(int32)
queueLength(int32)
fileCount(int32)
files[]:
  code(int32)
  filename(string)
  size(int32)
  extension(string)
  attributeCount(int32)
  types 0..3 with corresponding int32 values
```

## Obfuscation Handshake

Used to mask peer-to-peer connections from traffic shaping.

1. Each side generates a random 4-byte token
2. Tokens are exchanged in plaintext (first 4 bytes of TCP stream)
3. Shared key = XOR of both tokens
4. 256-byte key is derived using Pi digits: `key[i] = PiDigits[(combined + i) % len] ^ (combined >> ((i % 4) * 8))`
5. All subsequent traffic is XOR-encoded with this key (encode and decode are identical)

Pi digit source: hex digits of `π * 2^64` (first 128 bytes).

## Connection Lifecycle

```
Client                     Server
  |                          |
  |--- Login (code 1) ------>|
  |<-- LoginResponse (206) --|
  |--- SetListenPort (2) --->|
  |--- AddUser (5) --------->|  (for tracked users)
  |                          |
  |--- SearchRequest (26) -->|
  |<-- SearchResponse (28) --|
  |                          |
  |  (every 60s or so)
  |<-- Ping (40) ------------|
  |--- Pong (41) ----------->|
  |                          |
  |  (disconnect)
  |--- TCP FIN ------------->|
```

## Peer-to-Peer Lifecycle

```
Client A (Downloader)      Client B (Uploader)
  |                            |
  |--- TCP Connect ----------->|
  |  (optional obfuscation HS) |
  |--- TransferRequest (135) ->|
  |<-- TransferResponse (136) -|  (status=0)
  |  (data starts flowing)     |
  |<-- TransferResponse (136) -|  (chunk 1)
  |<-- TransferResponse (136) -|  (chunk 2)
  |  ...                       |
  |<-- TransferResponse (136) -|  (final chunk)
```

For browsing:
```
Client A                     Client B
  |                             |
  |--- TCP Connect ------------->|
  |--- FolderContents (131) ---->|
  |<-- FolderContentsReply (132)-|
  |--- TCP Close --------------->|
```

## Direction Constants

```
Download = 0  — remote peer sends file to us
Upload   = 1  — we send file to remote peer
```

## Error Responses

Transfer responses with non-zero status:
- `1` — Queue full / denied (uploader will queue the request)
- `2` — File not found on uploader's system

## Default Server

- **Host**: `server.slsknet.org`
- **Port**: `2244`

## Notes

- The protocol has no encryption — plaintext TCP with optional obfuscation
- No TLS/SSL support
- No password hashing on the client side (plaintext credentials sent to server)
- Version fields in login (minor=17, major=1, build=0) are the reference client identifiers
