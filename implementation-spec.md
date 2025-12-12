# Signature Manager – Phase 1 Implementation Spec (MVP)

## 1. Goals and Scope

- **Platform:** macOS Sonoma 14.0+, Apple Silicon + Intel.[1]
- **Clients:** Apple Mail (file-based + limited AppleScript), personal Gmail via Gmail API.[2][3]
- **Core flows:**  
  - Create/edit HTML signatures with inline Base64 images (local model).[4]
  - One‑click sync to Apple Mail accounts.  
  - One‑click sync to personal Gmail identities/aliases.  

Out of scope: iCloud/CloudKit sync, Google Workspace domain-wide delegation, iOS, browser extension (future phases).

***

## 2. Architecture

### 2.1 Project Structure

Single macOS app target `SignatureManager`:

- `App/`
  - `SignatureManagerApp.swift`
- `Models/`
  - `Signature.swift`
  - `MailAccount.swift`
  - `GmailAccount.swift`
  - `SyncMapping.swift`
- `Services/`
  - `SignatureStorageService.swift` (local JSON)
  - `MailSyncService.swift` (Apple Mail filesystem + AppleScript helper)
  - `GmailService.swift` (OAuth + Gmail API)
  - `KeychainService.swift` (OAuth token storage)
  - `HTMLValidationService.swift` (linting/warnings)
- `ViewModels/`
  - `SignatureListViewModel.swift`
  - `EditorViewModel.swift`
  - `SyncViewModel.swift`
- `Views/`
  - `MainView.swift`
  - `SignatureListView.swift`
  - `SignatureEditorView.swift`
  - `SyncSettingsView.swift`
  - `SignaturePreviewContainer.swift` (wraps WKWebView)
- `Infrastructure/`
  - `AppleScriptHelper.swift`
  - `FileIO.swift`
  - `GmailAPIModels.swift`
- `Resources/`
  - `PrivacyInfo.xcprivacy`
  - `Info.plist`

Pattern: MVVM + “service” layer; no business logic in SwiftUI views.[5]

***

## 3. Data Model and Storage

### 3.1 Local Files

Base directory:

- `~/Library/Application Support/SignatureManager/`  

Structure:

- `signatures/{uuid}.json` – one file per signature.  
- `accounts.json` – cache of Mail + Gmail accounts.  
- `sync_state.json` – last sync timestamps and conflict records.

### 3.2 Signature Model

```swift
struct SignatureAccountBinding: Codable, Identifiable {
    enum AccountType: String, Codable { case apple_mail, gmail }
    var id: String { "\(type.rawValue)::\(accountIdentifier)::\(aliasEmail ?? "")" }

    var type: AccountType
    var accountIdentifier: String      // Mail UUID or Gmail address
    var aliasEmail: String?
    var isDefault: Bool
    var lastSyncTime: Date?
}

struct SignatureModel: Codable, Identifiable {
    var id: UUID
    var name: String
    var htmlContent: String
    var created: Date
    var updated: Date
    var accounts: [SignatureAccountBinding]
}
```

### 3.3 Mail Accounts Cache

```swift
struct MailAccountCache: Codable {
    struct MailAccount: Codable, Identifiable {
        var id: String          // Mail account UUID (AccountsMap key)[web:40]
        var emailAddress: String
        var accountName: String
        var isICloud: Bool
        var lastRefresh: Date
    }

    var mailAccounts: [MailAccount]
}
```

### 3.4 Gmail Accounts Cache

Maps Gmail primary + aliases from `users.settings.sendAs`.[]

```swift
struct GmailAccountCache: Codable {
    struct GmailAccount: Codable, Identifiable {
        var id: String { emailAddress }
        var emailAddress: String
        var displayName: String
        var isPrimary: Bool
        var aliases: [String]
        var lastRefresh: Date
    }

    var accounts: [GmailAccount]
}
```

### 3.5 Storage Service

`SignatureStorageService` responsibilities:

- Ensure directory structure exists.  
- CRUD for `SignatureModel` (one JSON per file) using `Codable`.  
- Load and save `MailAccountCache` and `GmailAccountCache`.  
- Manage `sync_state.json` (per‑account last sync + conflict markers).  

All file I/O done through `FileIO` helper (atomic writes + backup).[]

***

## 4. Apple Mail Integration

### 4.1 Paths and Files

- Signature files: `~/Library/Mail/V10/MailData/Signatures/`.[]  
- iCloud signatures: `~/Library/Mobile Documents/com~apple~mail/Data/MailData/Signatures/`.[]  
- Meta
  - `AllSignatures.plist` – Signature UUID → display name.[]  
  - `AccountsMap.plist` – Account UUID → ordered list of signature UUIDs (first = default).[]  

### 4.2 MailSyncService Responsibilities

- Enumerate accounts (Mail UUID and email):  
  - Primary: AppleScript (`every account`, `email addresses`).[]  
  - Fallback: parse `com.apple.mail.plist` if AppleScript fails.[]  
- For a given `SignatureModel` + target Mail account:  
  - Create or update `.mailsignature` file.  
  - Update `AllSignatures.plist`.  
  - Update `AccountsMap.plist` (place signature UUID first when `isDefault == true`).  
- Manage Mail restart when needed.  

### 4.3 Signature File Writing

Implementation steps:

1. **Template extraction:**  
   - Read an existing `.mailsignature` file (first one found).  
   - Parse for `<body>`…`</body>` and keep everything outside body as template wrapper.[]  

2. **HTML injection:**  
   - Replace inner body content with `signature.htmlContent`.  
   - Do not touch XML header, DOCTYPE, or `<plist>` structure.[]  

3. **Atomic write:**  
   - Write to `{uuid}.mailsignature.tmp`.  
   - Replace existing file with `FileManager.replaceItemAt`.  
   - Optionally `fsync` file descriptor.  
   - Create `.backup` copy before first overwrite.[]  

4. **Metadata updates:**  
   - `AllSignatures.plist`: ensure entry `uuid → name`.  
   - `AccountsMap.plist`: update array for target account UUID (insert uuid at index 0 for default).  

5. **Conflict handling:**  
   - Before write, compare existing file modification time to cached `lastSyncTime`.  
   - If newer → show conflict warning in UI.  

### 4.4 Mail Restart Strategy

MVP behavior:

- If Mail is running:
  - Prompt: “Mail must be restarted to apply changes. Restart now?”  
  - If yes: run `killall Mail` then `open /Applications/Mail.app`.  
- If Mail not running:
  - Just perform file operations; no restart prompt.  

No attempt to “soft reload” signatures since Mail does not re‑read files dynamically.[]

***

## 5. Gmail Integration

### 5.1 KeychainService

Purpose: secure storage of access & refresh tokens per Gmail account.[]

- One `kSecClassGenericPassword` item per token type:
  - `service = com.signaturemanager.gmail.access`, `account = userEmail`.  
  - `service = com.signaturemanager.gmail.refresh`, `account = userEmail`.  
  - `service = com.signaturemanager.gmail.expiry`, `account = userEmail`.  
- Public API:
  - `storeTokens(for email: String, access: String, refresh: String, expiry: Date)`  
  - `loadTokens(for email: String) -> (access: String?, refresh: String?, expiry: Date?)`  
  - `clearTokens(for email: String)`  

### 5.2 OAuth Flow (Google)

Use native app flow with system browser + custom URL scheme.[]

- Custom scheme in Info.plist: `signaturemanager://oauth2callback`.  
- OAuth client type: “Desktop application”.  
- Scope: `https://www.googleapis.com/auth/gmail.settings.basic` only.[]  

Flow:

1. Construct authorization URL with `response_type=code`, redirect to custom scheme.  
2. Open with `NSWorkspace.shared.open`.  
3. Handle callback in `application(_:open:)` (or `onOpenURL` in SwiftUI) and extract `code`.  
4. POST to `https://oauth2.googleapis.com/token` to obtain `access_token`, `refresh_token`, `expires_in`.[]  
5. Store in Keychain and drive UI state: “Gmail connected as user@gmail.com”.  

Token refresh:

- Before each API call, if `expiry < now + 5min` → refresh with `grant_type=refresh_token`.[]  
- If refresh returns 401 → clear tokens + prompt re‑auth.[]  

### 5.3 GmailService Responsibilities

- Fetch send-as identities (aliases):  
  - `GET /users/me/settings/sendAs`.[]  
- Update signature for one send-as identity:  
  - `PUT /users/me/settings/sendAs/{sendAsEmail}` with `{"signature": "<html>...</html>"}`.[]  
- Conflict detection:  
  - Fetch current `signature` first; compare hash with cached remote.  
- Error handling:
  - 401 → attempt refresh; if fails, ask user to re‑connect.  
  - 403/404 → show user-friendly explanation.  
  - 429 → exponential backoff using async/await and `Task.sleep`.[]  

Data models: map directly to Gmail `SendAs` resource: `sendAsEmail`, `displayName`, `signature`, `isDefault`, etc.[]

### 5.4 HTML + Image Constraints

- Accept raw HTML directly in `signature` field.  
- Do not attempt to send Base64 `image/...` URIs, as Gmail strips them.[]  
- Lint and warn if Base64 images present or unsupported tags/attributes used.[]  

***

## 6. HTML Editing and Preview

### 6.1 HTML ValidationService

Purpose: static analysis of HTML for cross‑client issues.

Checks:

- Unsafe tags: `script`, `iframe`, `object`, `embed`, `form`.[]  
- Unsafe attributes: `onclick`, `onload`, `onerror`, etc.  
- Base64 inline images: `image/` → Gmail warning.[]  
- `@media` rules → “ignored in Gmail, used in Mail” notice.[]  
- Size threshold (e.g., htmlContent length > 500 KB) → performance warning.[]  

Returns array of `ValidationWarning { id, message, severity }`.

### 6.2 EditorViewModel

State:

- `@Published var selectedSignature: SignatureModel?`  
- `@Published var htmlContent: String`  
- `@Published var validationWarnings: [ValidationWarning]`  
- `@Published var isDirty: Bool`  

Responsibilities:

- Load selected signature into editor.  
- Run validation on change (debounced).  
- Save back to `SignatureStorageService` (update `updated` timestamp).  

### 6.3 Preview Pane

`SignaturePreviewContainer` wraps a `WKWebView` (via `NSViewRepresentable`).[][]

Behavior:

- Receives HTML string from `EditorViewModel`.  
- Wraps it in minimal HTML scaffold (doctype, `<head>`, base styles).  
- Calls `loadHTMLString` on each update (with throttling to avoid over-refresh).[]  

***

## 7. Sync ViewModel and UI

### 7.1 SyncViewModel

State:

- `@Published var mailAccounts: [MailAccountCache.MailAccount]`  
- `@Published var gmailAccounts: [GmailAccountCache.GmailAccount]`  
- `@Published var syncInProgress: Bool`  
- `@Published var lastError: String?`  

APIs:

- `refreshAccounts()` → calls `MailSyncService.listAccounts()`, `GmailService.listAccounts()` and caches.  
- `syncSignatureToMail(signature: SignatureModel, accountId: String)`  
- `syncSignatureToGmail(signature: SignatureModel, sendAsEmail: String)`  

Each sync call:

1. Run HTML validation; if serious issues (e.g., Base64 for Gmail) → prompt user to confirm.  
2. For Mail:
   - Check conflict (modification time vs last sync).  
   - If conflict → confirm overwrite.  
   - Call `MailSyncService.applySignature(...)`.  
3. For Gmail:
   - Fetch current signature for identity.  
   - If differs from cached remote → conflict prompt.  
   - Call `GmailService.updateSignature(...)`.  

### 7.2 MainView / Flow

- Left: signature list  
- Center: HTML editor + warnings.  
- Right: preview pane + “Sync” sidebar:  
  - Section “Apple Mail accounts” (checkboxes per account, “Set as default”).  
  - Section “Gmail accounts & aliases” (checkboxes per send‑as).  
  - Buttons:
    - “Sync to Apple Mail”  
    - “Sync to Gmail”  

Permission UX:

- If Mail path access fails → show guided dialog to Full Disk Access panel (open System Settings URL).  
- If AppleScript call denied → show Automation permission instructions.  
- If Gmail not connected → show “Connect Gmail” button launching OAuth flow.  

***

## 8. Permissions, Entitlements, Privacy

### 8.1 Entitlements

- `com.apple.security.files.user-selected.read-write = true`.[]  
- `com.apple.security.automation = true`.[]  

App relies on user-granted Full Disk Access; no temporary path exceptions needed.[]

### 8.2 Privacy Manifest

Declare Mail data access and automation reason codes per Apple’s current privacy manifest spec.[]  

- Data categories: Mail signatures and account identifiers (local only).  

***

## 9. Testing Strategy

### 9.1 Unit Tests

- `SignatureStorageService` – save/load, corrupt JSON handling.  
- `HTMLValidationService` – each rule.  
- `GmailService` – request construction + error parsing with mocked responses.[]  
- `MailSyncService` – plist read/write using test fixtures (no real Mail usage).  

### 9.2 Integration Tests / Manual

On both Apple Silicon and Intel Macs:

- Fresh Sonoma user profile with at least:
  - One iCloud Mail account.  
  - One IMAP/Gmail account in Apple Mail.[]  
- One personal Gmail account with:
  - Primary address.  
  - One alias (send-as).  

Scenarios:

- Create new signature → sync to Mail (iCloud + Gmail‑IMAP).  
- Edit signature in app → resync; ensure Mail shows updated default.[]  
- Edit signature in Mail → detect conflict and prompt.  
- Gmail:
  - Create signature in app → sync primary send‑as.  
  - Confirm HTML rendered as expected in Gmail web UI.[]  
  - Large images / Base64 → confirm warnings and behavior.  

***

## 10. Implementation Phasing (MVP)

**Phase 1: Foundations**

- Project setup, models, local storage, HTML validator.  
- Simple editor + preview pane (no sync).  

**Phase 2: Apple Mail sync**

- Implement `MailSyncService` (filesystem + plist).  
- Account enumeration (AppleScript + fallback).  
- UI for Mail accounts + “Sync to Mail”.  

**Phase 3: Gmail OAuth + sync**

- OAuth flow + Keychain storage.  
- GmailService: list send-as, update signature.  
- UI for Gmail accounts + “Sync to Gmail”.  

**Phase 4: Conflicts, errors, permissions UX**

- Conflict detection overlays.  
- Full Disk Access + Automation onboarding UI.  
- Gmail error handling/backoff.  

**Phase 5: Hardening**

- Unit test coverage.  
- Manual matrix testing (Apple Silicon/Intel, different Mail setups).  
- Code signing + notarization scripts.  

***

This gives you a concrete, repo‑ready implementation spec aligned with the research you already have; you can refine class and method names as you start coding.

Sources
[1] Create and use email signatures in Mail on Mac - Apple Support https://support.apple.com/guide/mail/create-and-use-email-signatures-mail11943/mac
[2] Where are my Mail signatures? - Apple Support Communities https://discussions.apple.com/thread/255617159
[3] REST Resource: users.settings.sendAs | Gmail https://developers.google.com/workspace/gmail/api/reference/rest/v1/users.settings.sendAs
[4] Showing Local HTML Content in a WKWebView - Swift Dev Journal https://swiftdevjournal.com/showing-local-html-content-in-a-wkwebview/
[5] SwiftUI on macOS: text, rich text, markdown, html and PDF views ... https://eclecticlight.co/2024/05/07/swiftui-on-macos-text-rich-text-markdown-html-and-pdf-views-source-code/

