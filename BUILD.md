# Build Guide — Scout Android APK

**TL;DR — Quick start for Linux users:**
```bash
git push origin main
# Go to GitHub → Actions → download APK artifact
```

**TL;DR — Quick start for Windows/macOS:**
```bash
dotnet workload install maui
dotnet publish Soulseek.Maui -f net8.0-android -c Release -o apk
adb install apk/*.apk
```

---

## What Was Built

### App Structure (Soulseek.Maui — 47 files, ~8,500 lines)

```
Soulseek.Maui/
├── Soulseek.Maui.csproj       # Targets net8.0-android
├── MauiProgram.cs             # DI setup — 8 singletons + pages
├── App.xaml/.cs               # Entry point, auto-connect, converters
├── AppShell.xaml/.cs          # 7 tabs with SVG icons
├── Converters/Converters.cs   # 9 value converters
├── Services/
│   ├── SettingsService.cs      # Preferences + SecureStorage wrapper
│   ├── NotificationService.cs  # Android notification channels (PM, downloads, system)
│   └── SoulseekClientService.cs  # Singleton: connect, search, browse, download
├── ViewModels/ (8 files)
│   ├── LoginViewModel.cs       # Credentials, save password, server config, auto-connect
│   ├── SearchViewModel.cs      # Grouped by user, filter by type, swipe to download/browse
│   ├── RoomsViewModel.cs       # Joined room list, switch rooms, send/receive
│   ├── PrivateMessagesViewModel.cs  # Conversation threading, unread badges, notifications
│   ├── DownloadsViewModel.cs   # Active/completed, filter toggle, notification on complete
│   ├── BrowseViewModel.cs      # Folder tree grouped, swipe to download
│   ├── WishlistViewModel.cs    # Add/remove items, persisted locally
│   └── SettingsViewModel.cs    # Server, notifications, storage, reset
├── Views/ (16 files — 8 XAML + 8 code-behind)
│   ├── LoginPage               # Username, password, save toggle, server settings
│   ├── SearchPage              # Query bar, filter picker, grouped results, swipe actions
│   ├── RoomsPage               # Join bar, joined rooms picker, message list, send bar
│   ├── PrivateMessagesPage     # Conversation sidebar + message view, send bar
│   ├── DownloadsPage           # Progress bars, state colors, filter toggle
│   ├── BrowsePage              # Username entry, grouped folder tree, swipe to download
│   ├── WishlistPage            # Add/remove items, swipe to delete
│   └── SettingsPage            # Server, privacy, notifications, downloads path, about
├── Platforms/Android/
│   ├── AndroidManifest.xml     # INTERNET, storage, notifications, foreground service
│   ├── MainActivity.cs         # Notification channel creation (PM, downloads, system)
│   └── MainApplication.cs
├── Resources/
│   ├── AppIcon/appicon.svg     # Scout logo (green circle on dark)
│   ├── Splash/splash.svg       # Logo + "Scout" text
│   ├── Images/*.svg            # 6 tab icons (search, rooms, pm, downloads, browse, settings)
│   └── Styles/{Colors,Styles}.xaml  # Dark theme (Spotify-like)
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Dark theme only | Soulseek is a music app; dark theme fits the use case and saves battery |
| SVG icons for tabs | Vector icons scale perfectly; no external icon font dependency |
| Singletons for tab VMs | Shared state across tabs (e.g., Browse from Search) requires same VM instance |
| Persistent wishlist | Saved to Preferences so items survive app restart |
| SecureStorage for password | Android EncryptedSharedPreferences backing |
| Downloads to `Downloads/Scout/` | Standard Android download location, visible in file managers |
| Notification channels | Android 8+ requires channels for all notifications |
| Auto-connect on launch | If credentials saved and auto-connect enabled, connects immediately |
| PM conversation threading | Messages grouped by user with unread badges |
| Swipe actions on search/browse | Download or browse user with a swipe gesture |
| Filter by file type | Search results can be filtered to audio/video/image/document/archive |

---

> **Note:** MAUI workloads are not available on Linux. Linux users must use **GitHub Actions** (Option A below) or **cross-compile from Windows/macOS** (Option B). Skip straight to "Build via GitHub Actions" if you're on Linux.

## Step 1 — Choose Your Build Method

### Option A — Build via GitHub Actions (Linux, no local SDK needed)

This is the **recommended method for Linux** users. The CI builds the APK in the cloud.

1. Push the repo to GitHub:
```bash
git add -A
git commit -m "Add MAUI Android app"
git push origin main
```

2. Go to your repo on GitHub → **Actions** tab → select **build** workflow → **Run workflow** (or it runs automatically on push)

3. When the workflow finishes (~5 min), click the workflow run → **apk** job → **Upload APK** artifact → download the zip

4. Inside the zip: `com.soulseek.scout.apk` — transfer to phone and install

You can also trigger builds any time from the Actions tab without pushing.

### Option B — Build locally on Windows or macOS

If you have access to a Windows or macOS machine, follow the steps below.

## Prerequisites (Windows/macOS)

On your **PC** (Windows, macOS, or Linux):

### Install .NET 8 SDK

```bash
# Check if you have it:
dotnet --version
# Should be 8.0.x. If not:
# Windows/macOS: https://dotnet.microsoft.com/download/dotnet/8.0
# Ubuntu/Debian:
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 8.0
```

### Install MAUI Android Workload

```bash
dotnet workload install maui-android
# Verify:
dotnet workload list
# Should show: maui-android
```

### Install Android SDK

**Option A — Via Visual Studio 2022 (Windows):**
- Install Visual Studio 2022 Community+
- Select "Mobile development with .NET" workload
- Android SDK 34+ is included

**Option B — Command-line (Linux/macOS):**

```bash
# Install Android SDK command-line tools
mkdir -p ~/Android/cmdline-tools
cd ~/Android/cmdline-tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-*.zip
mv cmdline-tools latest
export ANDROID_HOME=$HOME/Android
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin

# Accept licenses and install platform
yes | sdkmanager --licenses
sdkmanager "platforms;android-34" "build-tools;34.0.0"
```

Set environment variables permanently:
```bash
echo 'export ANDROID_HOME=$HOME/Android' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> ~/.bashrc
```

---

## Step 2 — Build the APK

```bash
# From the repo root (/home/vokiry/Проекты/Scout):
dotnet restore

# Build (Debug for testing, Release for distribution):
dotnet build Soulseek.Maui -f net8.0-android -c Debug

# Generate APK via publish:
dotnet publish Soulseek.Maui -f net8.0-android -c Debug -o apk-output
```

The APK will be at:
```
apk-output/com.soulseek.scout.apk
# or:
apk-output/Soulseek.Maui-Signed.apk
```

### For Release (signed APK):

Create a keystore (one time):
```bash
keytool -genkey -v -keystore scout.keystore -alias scout -keyalg RSA -keysize 2048 -validity 10000
```

Build signed:
```bash
dotnet publish Soulseek.Maui \
  -f net8.0-android \
  -c Release \
  -p:AndroidKeyStore=true \
  -p:AndroidSigningKeyStore=scout.keystore \
  -p:AndroidSigningKeyAlias=scout \
  -p:AndroidSigningKeyPass=<password> \
  -p:AndroidSigningStorePass=<password> \
  -o apk-release
```

### Build Output Size

- Debug APK: ~15-20 MB
- Release APK (trimmed): ~8-12 MB

---

## Step 3 — Install on Phone

### Option A — ADB (wired, recommended)

1. Enable **Developer Options** on your Android phone:
   - Settings → About Phone → Tap "Build Number" 7 times
2. Settings → Developer Options → Enable **USB Debugging**
3. Connect phone via USB cable
4. On phone, accept the USB debugging prompt
5. On PC:

```bash
# Verify device is detected:
adb devices
# Should show: <device_id> device

# Install:
adb install apk-output/com.soulseek.scout.apk

# Or if installing a release APK:
adb install apk-release/com.soulseek.scout.apk
```

### Option B — Sideload without PC

1. Upload the APK to Google Drive, Dropbox, or Telegram
2. On phone, download the APK file
3. Open the APK in your file manager
4. If prompted, enable "Install from unknown apps" for your file manager
5. Tap **Install**

---

## Step 4 — First Run

1. Open the **Scout** app (icon: green circle on dark background)
2. You'll see the **Login Screen**:
   - Enter your Soulseek username and password
   - Optionally toggle "Save password"
   - Optionally change server (default: `server.slsknet.org:2244`)
3. Tap **Sign In**
4. On success, the main interface appears with 7 bottom tabs:

| Tab | What you can do |
|-----|----------------|
| **Search** | Type a query, tap Search. Results group by user. Swipe a result right to **Download** or **Browse** that user. Filter by audio/video/etc. |
| **Rooms** | Type a room name, tap Join. Switch between joined rooms using the picker. Send and receive messages in real time. |
| **PMs** | Left sidebar: list of conversations. Tap a conversation to see messages. Type username + message, tap Send. New PMs show notifications. |
| **Downloads** | Progress bars with percentage/speed/state. Green = completed, Yellow = downloading, Red = failed. Toggle "Show All" to see completed. |
| **Browse** | Type a username, tap Browse. See their shared folders with files grouped. Swipe a file right to **Download**. |
| **Wishlist** | Add phrases (artist, album). Swipe right to remove. Persisted locally. |
| **Settings** | Configure server host/port, toggle password saving, toggle notifications, reset all settings. |

---

## Step 5 — Troubleshooting

### Build Fails

| Error | Fix |
|-------|-----|
| `NETSDK1136` The target framework `net8.0-android` was not found | Install MAUI workload: `dotnet workload install maui-android` |
| `ANDROID_HOME` not set | `export ANDROID_HOME=$HOME/Android` (or your SDK path) |
| `platforms;android-34` not installed | `sdkmanager "platforms;android-34"` |
| `Build failed with` ... `aapt2` | Install build tools: `sdkmanager "build-tools;34.0.0"` |
| `warning XA0105` `@(AndroidAarLibrary)` | Ignore (non-fatal) |
| NU1803: NuGet sources | `dotnet nuget add source https://api.nuget.org/v3/index.json -n nuget.org` |

### Install Fails

| Error | Fix |
|-------|-----|
| `INSTALL_FAILED_OLDER_SDK` | Phone is Android < 7.0 (API 24). Scout requires Android 7+. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Uninstall previous version first: `adb uninstall com.soulseek.scout` |
| App not installing from file manager | Enable "Install from unknown apps" for your file manager |
| `App not installed.` | The APK may be corrupt. Rebuild with `dotnet build -c Release` |

### Runtime Issues

| Issue | Fix |
|-------|-----|
| "Connection failed" | Check internet. Server may be down (try `server.slsknet.org:2244`) |
| "Authentication failed" | Wrong username/password. Reset in Settings. |
| Search returns nothing | Try broader terms. Some queries naturally get few results. |
| Download fails | The user may be offline or behind a firewall. Retry later. |
| Notification permissions denied | Grant notification access in Android Settings → Apps → Scout |
| Downloads don't save to phone | Grant storage permission. On Android 11+, Scout saves to `Downloads/Scout/` |

### If Nothing Works

Reset the app:
```bash
adb uninstall com.soulseek.scout
adb install -r apk-output/com.soulseek.scout.apk
```

---

## App Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│                   LoginPage                          │
│  username/password → Auth → auto-navigate to Shell  │
└──────────────────────┬──────────────────────────────┘
                       │ success
┌──────────────────────▼──────────────────────────────┐
│                    AppShell (7 tabs)                 │
│  Search  Rooms  PMs  Downloads  Browse  Wishlist  Set│
└─────────────────────────────────────────────────────┘
```

All ViewModels are **singletons** so state is preserved across tab switches. The `SoulseekClientService` is the central singleton holding the `SoulseekClient` instance. Observables flow from the protocol library → services → ViewModels → XAML bindings.

## What Each Tab Does End-to-End

1. **Search**: Query → `SoulseekClient.Search()` → server searches → `SearchResults` observable → ViewModel groups by user → CollectionView renders. Swipe to download triggers `SoulseekClientService.DownloadFileAsync()` which resolves peer address, connects, and starts transfer.

2. **Rooms**: Join → `SoulseekClient.JoinRoom()` → server confirms → room messages arrive via `RoomMessages` observable → CollectionView appends.

3. **PMs**: Messages arrive via `PrivateMessages` observable → ViewModel threads into conversations → notifications via `NotificationService`. Send calls `SoulseekClient.SendPrivateMessage()`.

4. **Downloads**: `DownloadProgress` observable → ViewModel updates `ObservableCollection` → progress bars bind to `Percentage`. Completion triggers notification.

5. **Browse**: Username → resolve peer address via `PeerAddressResponses` observable → connect → send `FolderContents` request → parse reply → display grouped by folder. Swipe to download uses same `DownloadFileAsync`.

6. **Wishlist**: `AddWishlistItem`/`RemoveWishlistItem` sends server messages. Items also saved locally in `Preferences` for persistence.

7. **Settings**: All settings stored in `Preferences` (simple key-value) + `SecureStorage` (password). Changes take effect on next connect.
