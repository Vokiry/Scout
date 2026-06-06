# Scout — Development Roadmap

## ✅ Completed

### Core Protocol (`soulseek_protocol`)
- [x] Project scaffolding (monorepo with workspace)
- [x] Protocol layer: message framing, binary buffer, message codes
- [x] Socket manager with DNS resolution (IPv4→IPv6), timeout, error classification
- [x] Reconnection manager with exponential backoff and jitter
- [x] Connection race condition handler
- [x] Obfuscation handshake (Pi + XOR)
- [x] Server connection: login, search, ping/pong, private messages, user status
- [x] Peer connection management
- [x] Download manager with progress tracking, concurrent limits (default 3), retry logic
- [x] Upload manager — incoming transfer request handling, accept/deny, 1MB chunk streaming, progress
- [x] SoulseekClient — high-level orchestration API with service composition
- [x] **Service Layer refactor** — AuthService, SearchService, ChatService, UserService extracted
- [x] **Browse shares** — BrowseService + FolderContentsReply parsing + peer connection request/response
- [x] **Wishlist searches** — WishlistService with add/remove items and match result stream
- [x] **Room chat** — RoomChatService with join/leave/send/events/roomlist/tickers
- [x] **Distributed network** — parent/child relay with state machine, search forwarding, max 10 branches
- [x] **Upload server socket** — PeerListener with ServerSocket, IncomingConnection adapter, transfer routing
- [x] **CI/CD** — GitHub Actions for Dart 3.12 analysis + tests on push/PR to main

### Flutter App (`soulseek_app`)
- [x] Flutter app shell: navigation, theme (Material 3 + warm accent)
- [x] Login screen with animated transitions
- [x] Search screen with deduplication, user grouping, chip filters
- [x] Result cards with speed/slots/files info, context menu
- [x] Download screen with tab filtering and waveform progress bar
- [x] Settings screen with connection status

## 📋 Medium Priority

- [ ] **Drift/SQLite persistence** — download queue survives app restart, settings storage, search history cache (Flutter SDK)
- [ ] **flutter_secure_storage** — encrypted credential storage (Keychain/Keystore) (Flutter SDK)
- [ ] **connectivity_plus listener** — network change detection (WiFi→mobile) with auto-reconnect (Flutter SDK)
- [ ] **Download Service** — background downloads (Android foreground service, iOS BGTaskScheduler) (Flutter SDK)
- [ ] **Chat screens** — private messaging UI + chat room list and messages (Flutter SDK — protocol layer done)
- [ ] **Browse shares UI** — expandable folder tree for browsing user files (Flutter SDK — protocol layer done)
- [ ] **Wishlist UI** — manage wishlist items, view match notifications (Flutter SDK — protocol layer done)
- [ ] **Upload management UI** — upload queue/status, shared folder configuration (Flutter SDK — protocol layer done)
- [ ] **Place in queue** — message types and handling for queue position requests/responses (Pure Dart)

## 🔧 Low Priority

- [ ] **iOS background downloads** — BGTaskScheduler integration (Flutter SDK)
- [ ] **Android foreground service** — persistent notification with download progress (Flutter SDK)
- [ ] **Push notifications** — wishlist matches, download completed (Flutter SDK)
- [ ] **Offline cache** — persist recent search results and user info (Flutter SDK)
- [ ] **F-Droid / APK distribution** (Flutter SDK)
- [ ] **Dark/light theme toggle** (Flutter SDK)
- [ ] **Localization** (i18n) (Flutter SDK)
- [ ] **User info response** — parse UserInfoReply peer message (Pure Dart)
- [ ] **Room search** — server code 152 for searching within rooms (Pure Dart)
- [ ] **Private room management** — add/remove users, dismember, toggle, ACL (Pure Dart)

## 🐞 Known Issues

- `flutter_secure_storage_linux` has a C++ build issue with Clang 22 on Linux (works on Android/iOS)
- iOS App Transport Security may require Info.plist configuration for Soulseek server connections
- NAT traversal is limited on mobile networks (CGNAT) — sharing may not work
