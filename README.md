# Scout

A modern mobile client for the Soulseek peer-to-peer music sharing network.

Built with Flutter for cross-platform support (Android, iOS, Linux) with a focus on stability, usability, and a clean interface inspired by Nicotine+.

## Features

- **Music Search** — search across thousands of users with real-time results, deduplication, and grouping by user
- **Smart Downloads** — segmented downloads with concurrent limits (configurable), retry logic, queue management, and waveform progress indicators
- **Upload Management** — incoming transfer request handling with accept/deny callbacks, file streaming in 1MB chunks, upload progress tracking, and concurrent upload limits
- **User Browsing** — explore shared files from other users with a request/response pattern over peer connections and parsed folder tree
- **Chat** — private messages and public chat rooms (join/leave rooms, room messages, user join/leave events, room list, room tickers)
- **Wishlist Searches** — persistent wishlist queries with add/remove items and streaming match results
- **Distributed Network** — parent/child relay for distributed search coverage with state machine and configurable branch limit
- **Resilient Networking** — automatic reconnection with exponential backoff, connection race condition handling, IPv4/IPv6 fallback, obfuscated handshake (Pi + XOR)
- **Service Layer Architecture** — extracted AuthService, SearchService, ChatService, UserService, BrowseService, WishlistService, RoomChatService from the monolithic client for testability
- **CI/CD** — GitHub Actions pipeline for Dart 3.12 static analysis and test suite on push/PR to main
- **Material Design 3** with custom visual flair — squircle cards, animated transitions, gradient placeholders

## Architecture

```
soulseek-flutter/
├── packages/
│   ├── soulseek_protocol/     # Pure Dart (268+ tests) — Soulseek protocol
│   │   ├── lib/src/
│   │   │   ├── messages/      # Binary serialization/deserialization
│   │   │   ├── connection/    # TCP sockets, reconnect, keepalive
│   │   │   ├── peer/          # Peer-to-peer connections, race handling, incoming listener
│   │   │   ├── transfer/      # Download/upload management
│   │   │   ├── services/      # Auth, Search, Chat, User, Browse, Wishlist, RoomChat
│   │   │   ├── network/       # Distributed network (parent/child relay)
│   │   │   └── obfuscation/   # Obfuscated handshake (Pi + XOR)
│   │   └── test/
│   └── soulseek_app/          # Flutter application
│       ├── lib/
│       │   ├── core/          # Theme, DI, routing
│       │   ├── services/      # Business logic layer
│       │   ├── state/         # Riverpod state management
│       │   └── ui/            # Screens & widgets
│       └── test/
└── pubspec.yaml               # Workspace root
```

## Tech Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| UI Framework | Flutter 3.44 | Cross-platform, native perf |
| State | Riverpod 2 | Testable, compile-safe, no BuildContext dependency |
| Networking | dart:io Socket | Full TCP control, no FFI needed |
| Persistence | drift (SQLite) | Type-safe, reactive streams |
| Secure Storage | flutter_secure_storage | Keychain/Keystore |
| Navigation | go_router | Declarative, deep links |
| Code Gen | freezed + json_serializable | Immutable data classes |

## Getting Started

### Prerequisites

- Flutter SDK 3.44+
- Dart SDK 3.12+

### Setup

```bash
git clone git@github.com:Vokiry/Scout.git
cd Scout
flutter pub get
```

### Run

```bash
cd packages/soulseek_app
flutter run
```

## Soulseek Protocol

Scout implements the Soulseek protocol from scratch in pure Dart. The protocol uses TCP with a simple binary framing:

```
[Length: u32 LE] [Code: u32 LE] [Payload: N bytes]
```

Key protocol features implemented:
- Server login, search, private messaging, user status, room chat, wishlist
- Peer-to-peer connections with obfuscated handshake (Pi shuffle + XOR)
- Connection race detection and resolution
- File transfer with segmented downloads, resume, concurrent limits, and retry
- Upload request handling with accept/deny, file streaming, progress tracking
- User browsing with folder contents request/response parsing
- Distributed network participation (parent/child relay, configurable branches)
- Incoming peer connection listener and routing to upload manager

## License

GNU General Public License v3.0
