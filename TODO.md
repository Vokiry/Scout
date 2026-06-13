# TODO — Remaining Work

## Manual Testing & Bug Fixes

- [ ] Test login flow (valid + invalid credentials)
- [ ] Test search (basic, unicode, empty query)
- [ ] Test private messaging (send, receive, notifications)
- [ ] Test room chat (join, send/receive messages)
- [ ] Test wishlist (add, remove, persistence)
- [ ] Test reconnection (airplane mode toggle)
- [ ] Test peer browse (if users available)
- [ ] Fix pre-existing test failures (4 known): ObfuscationHandshake, UploadManager, PrivateMessage roundtrip
- [ ] Investigate `ComputeKey()` IndexOutOfRangeException in ObfuscationHandshake

## Features (Not Yet Implemented)

- [ ] Place-in-queue polling (`PlaceInQueue` response)
- [ ] Privileges checking
- [ ] User info (avatar, description)
- [ ] Folder browsing with subdirectory support
- [ ] Room tickers display
- [ ] Private rooms
- [ ] Interest management (likes/dislikes)

## Polish

- [ ] Add app icon (currently placeholder)
- [ ] Add NuGet package readme for Soulseek.Protocol
- [ ] Sign APK for release distribution
- [ ] Add end-to-end tests for distributed network
- [ ] Improve error messages in the UI
- [ ] Add loading indicators during network operations
