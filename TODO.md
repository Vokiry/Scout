# Scout — Development Roadmap

## ✅ Completed

- [x] Project scaffolding (monorepo with workspace)
- [x] Protocol layer: message framing, binary buffer, message codes
- [x] Socket manager with DNS resolution (IPv4→IPv6), timeout, error classification
- [x] Reconnection manager with exponential backoff and jitter
- [x] Connection race condition handler
- [x] Obfuscation handshake (Pi + XOR)
- [x] Server connection: login, search, ping/pong, private messages, user status
- [x] Peer connection management
- [x] Download manager with progress tracking and segmented transfers
- [x] SoulseekClient — high-level orchestration API
- [x] Flutter app shell: navigation, theme (Material 3 + warm accent)
- [x] Login screen with animated transitions
- [x] Search screen with deduplication, user grouping, chip filters
- [x] Result cards with speed/slots/files info, context menu
- [x] Download screen with tab filtering and waveform progress bar
- [x] Settings screen with connection status

## 📋 Medium Priority

- [ ] **Drift/SQLite persistence** — download queue survives app restart, settings storage, search history cache
- [ ] **flutter_secure_storage** — encrypted credential storage (Keychain/Keystore)
- [ ] **connectivity_plus listener** — network change detection (WiFi→mobile) with auto-reconnect
- [ ] **Download Service** — background downloads (Android foreground service, iOS BGTaskScheduler)
- [ ] **Chat screens** — private messaging UI + chat room list and messages
- [ ] **Browse shares** — expandable folder tree for browsing user files
- [ ] **Service Layer refactor** — extract AuthService, SearchService, ChatService from monolithic client

## 🔧 Low Priority

- [ ] **iOS background downloads** — BGTaskScheduler integration
- [ ] **Android foreground service** — persistent notification with download progress
- [ ] **Upload management** — allow other users to download shared files
- [ ] **Distributed network (parent/child)** — improved search coverage
- [ ] **Push notifications** — wishlist matches, download completed
- [ ] **Offline cache** — persist recent search results and user info
- [ ] **CI/CD** — GitHub Actions for analysis, tests, builds
- [ ] **F-Droid / APK distribution**
- [ ] **Dark/light theme toggle**
- [ ] **Localization** (i18n)

## 🐞 Known Issues

- `flutter_secure_storage_linux` has a C++ build issue with Clang 22 on Linux (works on Android/iOS)
- iOS App Transport Security may require Info.plist configuration for Soulseek server connections
- NAT traversal is limited on mobile networks (CGNAT) — sharing may not work
