# SignatureManager

A powerful macOS application for seamlessly syncing email signatures between Apple Mail and Gmail, ensuring consistent branding across all your email clients.

## Features

- **Cross-Platform Sync**: Synchronize signatures between Apple Mail and Gmail
- **Rich HTML Editor**: Create and edit HTML signatures with real-time preview
- **Validation Engine**: Built-in compatibility checks for different email clients
- **Secure Storage**: OAuth tokens stored securely in macOS Keychain
- **Multiple Accounts**: Support for multiple Gmail accounts and Mail identities
- **Template Library**: Pre-built signature templates for quick setup
- **Conflict Resolution**: Smart handling of signature conflicts between services

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for development)
- Apple Mail (for Mail sync functionality)
- Internet connection (for Gmail sync)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/starfysh-tech/sigsync.git
   cd sigsync
   ```

2. Open the project in Xcode:
   ```bash
   open SignatureManager.xcodeproj
   ```

3. Build and run the application (⌘+R)

## Usage

### Getting Started

1. **Launch SignatureManager** from your Applications folder
2. **Create your first signature** using the built-in editor
3. **Connect your accounts**:
   - Apple Mail accounts are discovered automatically
   - Gmail accounts require OAuth authentication
4. **Sync signatures** to your desired accounts

### Creating Signatures

1. Click the **"+ New Signature"** button in the sidebar
2. Enter a descriptive name for your signature
3. Use the HTML editor to create your signature content
4. Preview your signature in real-time
5. Save your changes (⌘+S)

### Syncing to Services

#### Apple Mail
- Signatures are automatically synced to `~/Library/Mail/V10/MailData/Signatures/`
- Requires **Full Disk Access** permission for Mail data access
- Works with all configured Mail accounts

#### Gmail
- Requires OAuth authentication with Google
- Updates signature via Gmail API
- Supports multiple Gmail accounts and aliases

## Architecture

The application follows a clean MVVM (Model-View-ViewModel) architecture:

```
SignatureManager/
├── App/                    # Application entry point
├── Models/                 # Data models and structures
├── Views/                  # SwiftUI user interface
├── ViewModels/             # MVVM view models
├── Services/               # Business logic and API services
├── Infrastructure/         # Core utilities and helpers
└── Resources/              # Assets, entitlements, and configuration
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

### Building

```bash
# Clone the repository
git clone https://github.com/starfysh-tech/sigsync.git
cd sigsync

# Open in Xcode
open SignatureManager.xcodeproj

# Or build from command line
xcodebuild -project SignatureManager.xcodeproj -scheme SignatureManager build
```

### Testing

```bash
# Run unit tests
xcodebuild test -project SignatureManager.xcodeproj -scheme SignatureManager
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
