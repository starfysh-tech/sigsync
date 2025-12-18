# SignatureManager

A powerful macOS application for seamlessly syncing email signatures between Apple Mail and Gmail, ensuring consistent branding across all your email clients.

## Features

- **🚀 Auto-Discovery**: Automatically detects existing email accounts and imports signatures on first launch
- **🔄 Cross-Platform Sync**: Synchronize signatures between Apple Mail and Gmail
- **✏️ Rich HTML Editor**: Create and edit HTML signatures with real-time preview
- **✅ Validation Engine**: Built-in compatibility checks for different email clients
- **🔒 Secure Storage**: OAuth tokens stored securely in macOS Keychain
- **📧 Multiple Accounts**: Support for multiple Gmail accounts and Mail identities
- **📋 Template Library**: Pre-built signature templates for quick setup
- **⚡ Conflict Resolution**: Smart handling of signature conflicts between services

## Quick Start

```bash
# Clone, build, and run
git clone https://github.com/starfysh-tech/sigsync.git
cd sigsync
./build.sh --run
```

That's it! The application will build and launch automatically.

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)
- Apple Mail (for Mail sync functionality)
- Internet connection (for Gmail sync)

## Installation

### From Source

**Recommended: Use the build script**

```bash
git clone https://github.com/starfysh-tech/sigsync.git
cd sigsync
./build.sh --run
```

**Why use the build script?**
- ✅ **Fast**: Incremental builds (only rebuilds what changed)
- ✅ **Clean**: Shows only errors and warnings, not pages of output
- ✅ **Simple**: One command for everything (`./build.sh --run`)
- ✅ **Smart**: Handles all dependencies automatically

**Other options:**

Run `./build.sh --help` to see all options, or use Xcode:

**Use Xcode**

```bash
open SignatureManager.xcodeproj
# Build and run with ⌘+R
```

## Usage

### Getting Started

1. **Launch SignatureManager** - The app will automatically:
   - 🔍 Detect existing Apple Mail accounts
   - 📥 Import any existing Mail.app signatures
   - This happens only on first launch when no signatures exist

2. **Create or edit signatures** using the built-in HTML editor

3. **Connect additional accounts**:
   - Apple Mail accounts are auto-detected
   - Gmail accounts require OAuth authentication

4. **Sync signatures** to your desired accounts with one click

### Creating Signatures

1. Click the **"+ New Signature"** button in the sidebar
2. Enter a descriptive name for your signature
3. Use the HTML editor to create your signature content
4. Preview your signature in real-time
5. Save your changes (⌘+S)

### Syncing to Services

#### Apple Mail
- Signatures are automatically synced to `~/Library/Mail/V*/MailData/Signatures/`
- Automatically detects your Mail version (V8 through V12)
- Requires **Full Disk Access** permission for Mail data access
- Works with all configured Mail accounts

#### Gmail
- Requires OAuth authentication with Google
- Updates signature via Gmail API
- Supports multiple Gmail accounts and aliases

## Architecture

The application follows a clean MVVM (Model-View-ViewModel) architecture:

```
sigsync/
├── SignatureManager/           # Main application source
│   ├── App/                    # Application entry point
│   ├── Models/                 # Data models and structures
│   ├── Views/                  # SwiftUI user interface
│   ├── ViewModels/             # MVVM view models
│   ├── Services/               # Business logic and API services
│   ├── Infrastructure/         # Core utilities and helpers
│   └── Resources/              # Assets, entitlements, and configuration
├── SignatureManager.xcodeproj/ # Xcode project files
├── build.sh                    # Build script (./build.sh --help)
└── README.md                   # This file
```

### Key Components

- **[SignatureStorageService](SignatureManager/Services/SignatureStorageService.swift)**: Local JSON-based signature storage
- **[MailSyncService](SignatureManager/Services/MailSyncService.swift)**: Apple Mail integration via file system
- **[KeychainService](SignatureManager/Services/KeychainService.swift)**: Secure credential storage
- **[HTMLValidationService](SignatureManager/Services/HTMLValidationService.swift)**: Cross-client compatibility validation

## Permissions

SignatureManager requires the following permissions:

### Full Disk Access
Required for accessing Apple Mail signature files. To grant access:

1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Full Disk Access** from the sidebar
3. Click the lock icon and authenticate
4. Add SignatureManager to the list of allowed applications

### Automation (Optional)
For enhanced Apple Mail integration:

1. Open **System Preferences** → **Security & Privacy** → **Privacy**
2. Select **Automation** from the sidebar
3. Allow SignatureManager to control Mail.app

## Development

### Project Structure

The project uses modern Swift development practices:

- **SwiftUI** for the user interface
- **Combine** for reactive programming
- **MVVM** architecture pattern
- **Keychain Services** for secure storage
- **WebKit** for HTML preview

### Building from Command Line

**The paved road: Use `./build.sh`**

```bash
# Build and run (recommended for development)
./build.sh --run

# Just build (fast incremental builds)
./build.sh

# Build Release for distribution
./build.sh --release

# Build and run Release
./build.sh --release --run

# Force clean build (when things go wrong)
./build.sh --clean

# See all options
./build.sh --help
```

**Common workflows:**

```bash
# Daily development
./build.sh -r                    # Build and run Debug

# Testing before commit
./build.sh --clean --release     # Clean Release build

# Quick iteration
./build.sh && ./build.sh         # Fast incremental builds

# Build for distribution
./build.sh -R                    # Release build
```

**Build artifacts:**
- Debug: `build/Build/Products/Debug/SignatureManager.app`
- Release: `build/Build/Products/Release/SignatureManager.app`

### ⚠️ Full Disk Access During Development

**Important:** Each time you rebuild the app, macOS sees it as a "different app" because the code signature changes. This means:

- Full Disk Access permission is **revoked after every build**
- You must re-grant FDA permission each time during development
- Or use the built-in FDA Debug Tool (press `Cmd+Option+D` in the app)

**Workaround for development:**
1. Build once: `./build.sh`
2. Copy to a stable location: `cp -R build/Build/Products/Debug/SignatureManager.app ~/Applications/Dev/`
3. Grant FDA to the copy in System Settings
4. Run from that location for testing

This only affects development builds. Properly signed release builds don't have this issue.

### Testing

SignatureManager includes comprehensive behavior-focused tests that verify user-visible functionality without testing implementation details.

**Quick start:**

```bash
# Run all tests (after adding test target in Xcode - see below)
./build.sh --test

# Or use xcodebuild directly
xcodebuild test -project SignatureManager.xcodeproj \
                -scheme SignatureManager \
                -destination 'platform=macOS,arch=arm64'
```

**Test coverage includes:**

- ✅ **Auto-discovery**: First launch behavior, signature import, account detection
- ✅ **Signature import**: Parsing Mail.app files, format handling, error cases
- ✅ **Storage operations**: CRUD operations, persistence, conflict handling
- ✅ **Sync behavior**: Cross-platform synchronization logic

**Test infrastructure:**

- `SignatureManagerTests/Integration/` - End-to-end behavior tests
- `SignatureManagerTests/Services/` - Service-level behavior tests
- `SignatureManagerTests/TestHelpers/` - Mock implementations and fixtures

**One-time setup:**

Tests are written but need to be added to Xcode (one-time setup):

1. Open `SignatureManager.xcodeproj` in Xcode
2. Add a new **Unit Testing Bundle** target named `SignatureManagerTests`
3. Add test files from `SignatureManagerTests/` directory
4. Enable testability in main app target (Build Settings → "Enable Testability" → YES for Debug)

See **[SignatureManagerTests/README.md](SignatureManagerTests/README.md)** for detailed setup instructions and testing philosophy.

**Test philosophy:**

We test **behavior** (what users see), not **implementation** (how code works):

```swift
// ✅ Good: Tests user-visible behavior
func testFirstLaunch_WithExistingSignatures_ImportsThemAutomatically()

// ❌ Bad: Tests internal implementation
func testParseMailSignatureFileCallsPropertyListSerialization()
```

This approach ensures tests survive refactoring and catch real regressions.

### Installing to Applications

```bash
# Build Release and install
./build.sh --release
cp -R build/Build/Products/Release/SignatureManager.app /Applications/
```

## Contributing

We welcome contributions! Please see our [implementation specification](implementation-spec.md) for detailed technical requirements.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Commit your changes: `git commit -m 'Add amazing feature'`
5. Push to the branch: `git push origin feature/amazing-feature`
6. Open a Pull Request

## Privacy & Security

- **Local Storage**: Signatures are stored locally in `~/Library/Application Support/SignatureManager/`
- **Secure Credentials**: OAuth tokens are stored in macOS Keychain
- **No Tracking**: SignatureManager does not collect or transmit user data
- **Open Source**: Full source code is available for security review

## Troubleshooting

### Common Issues

**"Permission Denied" when syncing to Apple Mail**
- Ensure Full Disk Access is granted in System Preferences
- Restart SignatureManager after granting permissions

**Gmail authentication fails**
- Check your internet connection
- Verify that third-party app access is enabled in your Google account
- Clear stored credentials and re-authenticate

**Signatures not appearing in Mail**
- Restart Apple Mail after syncing
- Check that the correct Mail account is selected
- Verify signature files exist in `~/Library/Mail/V10/MailData/Signatures/`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: Report bugs and feature requests on [GitHub Issues](https://github.com/starfysh-tech/sigsync/issues)
- **Discussions**: Join the conversation in [GitHub Discussions](https://github.com/starfysh-tech/sigsync/discussions)

---

Made with ❤️ for the macOS community
