import Foundation
import OSAKit
import CryptoKit

enum MailAccessStatus: Equatable {
    case granted
    case permissionDenied
    case mailNotConfigured
    
    var userMessage: String {
        switch self {
        case .granted:
            return "Mail access available"
        case .permissionDenied:
            return """
Full Disk Access Required

To import signatures from Mail.app:
1. Open System Settings > Privacy & Security > Full Disk Access
2. Click the lock icon (bottom left) to unlock
3. Click the "+" button
4. Navigate to: \(Bundle.main.bundleURL.path)
5. Select SignatureManager.app and click Open
6. Make sure the toggle is ON
7. Click Retry Discovery in this app
"""
        case .mailNotConfigured:
            return "Mail.app has not been set up yet. Configure Mail accounts in the Mail app first, then try again."
        }
    }
    
    var isAccessible: Bool {
        return self == .granted
    }
}

enum MailSyncError: Error {
    case mailNotInstalled
    case mailNotRunning
    case permissionDenied
    case signatureDirectoryNotFound
    case signatureWriteFailed
    case accountDiscoveryFailed
    case invalidSignatureFormat
    
    var localizedDescription: String {
        switch self {
        case .mailNotInstalled:
            return "Apple Mail is not installed"
        case .mailNotRunning:
            return "Apple Mail is not running"
        case .permissionDenied:
            return "Permission denied to access Mail data"
        case .signatureDirectoryNotFound:
            return "Mail signatures directory not found"
        case .signatureWriteFailed:
            return "Failed to write signature file"
        case .accountDiscoveryFailed:
            return "Failed to discover Mail accounts"
        case .invalidSignatureFormat:
            return "Invalid signature format"
        }
    }
}

class MailSyncService {
    static let shared = MailSyncService()
    
    private let fileManager = FileManager.default
    
    // FIXED: Removed circular dependency
    // DO NOT store SignatureStorageService.shared here as it creates a deadlock
    // Pass it as a parameter to methods that need it
    
    private init() {}
    
    // MARK: - Mail Directory Paths
    
    private var mailDataDirectory: URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        let mailDirectory = homeDirectory.appendingPathComponent("Library/Mail")
        
        // Try to detect Mail version dynamically (V8 through V12)
        for version in (8...12).reversed() {
            let versionedPath = mailDirectory.appendingPathComponent("V\(version)/MailData")
            if fileManager.fileExists(atPath: versionedPath.path) {
                NSLog("📧 Detected Mail version: V\(version)")
                return versionedPath
            }
        }
        
        // Fallback to V10 if detection fails
        NSLog("⚠️ Could not detect Mail version, using V10 as fallback")
        return mailDirectory.appendingPathComponent("V10/MailData")
    }
    
    private var signaturesDirectory: URL {
        mailDataDirectory.appendingPathComponent("Signatures")
    }
    
    private var accountsDirectory: URL {
        mailDataDirectory.appendingPathComponent("Accounts")
    }
    
    // MARK: - Permission Checking
    
    func checkMailAccessPermission() -> MailAccessStatus {
        let mailDir = mailDataDirectory
        
        NSLog("🔍 Checking FDA for Mail directory: %@", mailDir.path)
        
        // Check if Mail directory exists
        guard fileManager.fileExists(atPath: mailDir.path) else {
            NSLog("   ℹ️ Mail directory doesn't exist - Mail.app not configured")
            return .mailNotConfigured
        }
        
        // ONLY trust actual access attempt - DO NOT use isReadableFile()!
        // isReadableFile() checks Unix permissions (always true for user's home dir)
        // TCC (Full Disk Access) is a separate layer that can block even "readable" files
        // The ONLY reliable test is to actually try reading the directory
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: mailDir.path)
            NSLog("   ✅ FDA granted - read %d items: %@", contents.count, contents.joined(separator: ", "))
            
            // Verify we found actual Mail data
            let hasAccounts = contents.contains("Accounts")
            let hasSignatures = contents.contains("Signatures")
            
            if !hasAccounts && !hasSignatures {
                NSLog("   ⚠️ Directory accessible but no Mail data (Accounts/Signatures missing)")
                return .mailNotConfigured
            }
            
            // Write success to debug file
            let debugLog = "/tmp/sigsync_permission_debug.txt"
            let debugInfo = """
            🔍 Permission Check at \(Date())
            Mail directory: \(mailDir.path)
            ✅ FDA granted
            Found \(contents.count) items: \(contents.joined(separator: ", "))
            """
            try? debugInfo.write(toFile: debugLog, atomically: true, encoding: .utf8)
            
            return .granted
            
        } catch let error as NSError {
            NSLog("   ❌ FDA denied - TCC blocked access")
            NSLog("      Error: %@ (domain: %@, code: %ld)", 
                  error.localizedDescription, error.domain, error.code)
            
            // Write failure to debug file
            let debugLog = "/tmp/sigsync_permission_debug.txt"
            let debugInfo = """
            🔍 Permission Check at \(Date())
            Mail directory: \(mailDir.path)
            ❌ FDA denied
            Error: \(error.localizedDescription)
            Domain: \(error.domain)
            Code: \(error.code)
            
            To fix:
            1. Open System Settings > Privacy & Security > Full Disk Access
            2. Click lock icon to unlock
            3. Remove any old SignatureManager entries
            4. Click + and add: \(Bundle.main.bundleURL.path)
            5. Toggle ON
            6. Restart this app
            """
            try? debugInfo.write(toFile: debugLog, atomically: true, encoding: .utf8)
            
            // Check error type for classification
            if error.domain == NSCocoaErrorDomain && 
               (error.code == NSFileReadNoPermissionError || error.code == 257) {
                return .permissionDenied
            }
            
            // Check error message for permission indicators
            let message = error.localizedDescription.lowercased()
            if message.contains("permission") || message.contains("not permitted") {
                return .permissionDenied
            }
            
            // Unknown error - treat as permission issue to be safe
            NSLog("      Treating as permission error")
            return .permissionDenied
        }
    }
    
    func requestMailAccessPermission() {
        // Attempt to access the Mail directory, which will trigger a system prompt
        // if the app hasn't been granted permission yet
        let mailDir = mailDataDirectory
        do {
            _ = try fileManager.contentsOfDirectory(atPath: mailDir.path)
            print("✅ Already have permission to access Mail directory")
        } catch {
            print("⚠️ Permission denied - user needs to manually grant Full Disk Access")
            print("   App location: \(Bundle.main.bundleURL.path)")
        }
    }
    
    // MARK: - Account Discovery
    
    func discoverMailAccounts() async throws -> [MailAccountCache.MailAccount] {
        guard fileManager.fileExists(atPath: mailDataDirectory.path) else {
            throw MailSyncError.signatureDirectoryNotFound
        }
        
        var accounts: [MailAccountCache.MailAccount] = []
        
        // Try AppleScript approach first
        if let scriptAccounts = try? await discoverAccountsViaAppleScript() {
            accounts.append(contentsOf: scriptAccounts)
        }
        
        // Fallback to file system discovery
        if accounts.isEmpty {
            accounts = try discoverAccountsViaFileSystem()
        }
        
        // FIXED: Return accounts for caller to cache
        // Don't update storage here to avoid circular dependency
        return accounts
    }
    
    private func discoverAccountsViaAppleScript() async throws -> [MailAccountCache.MailAccount] {
        let script = """
        tell application "Mail"
            set accountList to {}
            repeat with acc in accounts
                set accountInfo to {name of acc, user name of acc, email addresses of acc}
                set end of accountList to accountInfo
            end repeat
            return accountList
        end tell
        """
        
        let appleScript = OSAScript(source: script)
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript error: \(error)")
            throw MailSyncError.accountDiscoveryFailed
        }
        
        guard let result = result else {
            throw MailSyncError.accountDiscoveryFailed
        }
        
        return parseAppleScriptAccountResult(result)
    }
    
    private func parseAppleScriptAccountResult(_ result: NSAppleEventDescriptor) -> [MailAccountCache.MailAccount] {
        var accounts: [MailAccountCache.MailAccount] = []
        
        // AppleScript lists use 1-based indexing
        let accountCount = result.numberOfItems
        
        for i in 1...accountCount {
            guard let accountRecord = result.atIndex(i) else { continue }
            
            // Each record is a list: {name, userName, emailAddresses}
            guard accountRecord.numberOfItems >= 3 else { continue }
            
            let accountName = accountRecord.atIndex(1)?.stringValue ?? "Unknown"
            _ = accountRecord.atIndex(2)?.stringValue // userName (unused but part of AppleScript result)
            
            // Email addresses is a list
            guard let emailList = accountRecord.atIndex(3) else { continue }
            
            // Get the first email address (primary)
            var emailAddress = ""
            if emailList.numberOfItems > 0,
               let firstEmail = emailList.atIndex(1)?.stringValue {
                emailAddress = firstEmail
            }
            
            // Skip accounts without email
            guard !emailAddress.isEmpty else { continue }
            
            let isICloud = accountName.lowercased().contains("icloud") || 
                          emailAddress.lowercased().contains("icloud.com")
            
            accounts.append(MailAccountCache.MailAccount(
                id: UUID().uuidString,
                emailAddress: emailAddress,
                accountName: accountName,
                isICloud: isICloud,
                lastRefresh: Date()
            ))
        }
        
        return accounts
    }
    
    private func discoverAccountsViaFileSystem() throws -> [MailAccountCache.MailAccount] {
        guard fileManager.fileExists(atPath: accountsDirectory.path) else {
            return []
        }
        
        let accountDirectories = try fileManager.contentsOfDirectory(at: accountsDirectory, includingPropertiesForKeys: nil)
        var accounts: [MailAccountCache.MailAccount] = []
        
        for accountDir in accountDirectories {
            if let account = try? parseAccountDirectory(accountDir) {
                accounts.append(account)
            }
        }
        
        return accounts
    }
    
    private func parseAccountDirectory(_ directory: URL) throws -> MailAccountCache.MailAccount? {
        let accountId = directory.lastPathComponent
        
        // Try to read Info.plist from the account directory
        let infoPlistPath = directory.appendingPathComponent("Info.plist")
        
        guard fileManager.fileExists(atPath: infoPlistPath.path) else {
            return nil
        }
        
        guard let plistData = try? Data(contentsOf: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }
        
        // Extract email addresses (usually stored as an array)
        var emailAddress = ""
        if let emailAddresses = plist["EmailAddresses"] as? [String], !emailAddresses.isEmpty {
            emailAddress = emailAddresses[0]
        } else if let email = plist["EmailAddress"] as? String {
            emailAddress = email
        }
        
        // Skip if no email found
        guard !emailAddress.isEmpty else {
            return nil
        }
        
        // Extract account name
        let accountName = (plist["AccountName"] as? String) ?? 
                         (plist["FullUserName"] as? String) ?? 
                         emailAddress
        
        // Determine if it's an iCloud account
        let accountType = plist["AccountType"] as? String ?? ""
        let isICloud = accountType.contains("iCloud") || 
                      accountName.lowercased().contains("icloud") ||
                      emailAddress.lowercased().contains("icloud.com")
        
        return MailAccountCache.MailAccount(
            id: accountId,
            emailAddress: emailAddress,
            accountName: accountName,
            isICloud: isICloud,
            lastRefresh: Date()
        )
    }
    
    // MARK: - Signature Sync
    
    func syncSignatureToMail(_ signature: SignatureModel, account: MailAccountCache.MailAccount, storageService: SignatureStorageService) async throws {
        try ensureSignaturesDirectoryExists()
        
        let signatureFileName = "\(signature.id.uuidString).mailsignature"
        let signatureFilePath = signaturesDirectory.appendingPathComponent(signatureFileName)
        
        let mailSignatureContent = try createMailSignatureContent(signature)
        
        try mailSignatureContent.write(to: signatureFilePath, atomically: true, encoding: .utf8)
        
        // Update the signature mapping
        storageService.updateSyncRecord(
            for: account.id,
            accountType: .apple_mail,
            remoteHash: signature.htmlContent.sha256
        )
    }
    
    private func ensureSignaturesDirectoryExists() throws {
        if !fileManager.fileExists(atPath: signaturesDirectory.path) {
            try fileManager.createDirectory(at: signaturesDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func createMailSignatureContent(_ signature: SignatureModel) throws -> String {
        // Create the .mailsignature file format
        // This is a simplified version - the actual format is more complex
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>SignatureName</key>
            <string>\(signature.name)</string>
            <key>SignatureText</key>
            <string>\(signature.htmlContent.xmlEscaped)</string>
            <key>SignatureUniqueId</key>
            <string>\(signature.id.uuidString)</string>
            <key>SignatureVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """
        
        return plistContent
    }
    
    // MARK: - Signature Import
    
    func importExistingSignatures() async throws -> [SignatureModel] {
        guard fileManager.fileExists(atPath: signaturesDirectory.path) else {
            return []
        }
        
        let signatureFiles = try fileManager.contentsOfDirectory(at: signaturesDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mailsignature" }
        
        var importedSignatures: [SignatureModel] = []
        
        for fileURL in signatureFiles {
            if let signature = try? parseMailSignatureFile(fileURL) {
                importedSignatures.append(signature)
            }
        }
        
        return importedSignatures
    }
    
    private func parseMailSignatureFile(_ fileURL: URL) throws -> SignatureModel? {
        let data = try Data(contentsOf: fileURL)
        
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        
        guard let signatureName = plist["SignatureName"] as? String,
              let signatureText = plist["SignatureText"] as? String else {
            return nil
        }
        
        // Clean up the signature text - it might contain RTF or plain text
        let htmlContent = convertToHTML(signatureText)
        
        var signature = SignatureModel(name: signatureName, htmlContent: htmlContent)
        
        // Try to extract UUID if it exists
        if let signatureId = plist["SignatureUniqueId"] as? String,
           let uuid = UUID(uuidString: signatureId) {
            signature.id = uuid
        }
        
        return signature
    }
    
    private func convertToHTML(_ text: String) -> String {
        // If it's already HTML, return as-is
        if text.lowercased().contains("<html") || text.lowercased().contains("<!doctype") {
            return text
        }
        
        // If it contains HTML tags, wrap it
        if text.contains("<") && text.contains(">") {
            return text
        }
        
        // Otherwise, convert plain text to HTML
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
        
        return "<div style=\"font-family: system-ui, -apple-system, sans-serif;\">\(escapedText)</div>"
    }
    
    // MARK: - Signature Retrieval
    
    func getExistingSignatures() throws -> [String] {
        guard fileManager.fileExists(atPath: signaturesDirectory.path) else {
            return []
        }
        
        let signatureFiles = try fileManager.contentsOfDirectory(at: signaturesDirectory, includingPropertiesForKeys: nil)
        return signatureFiles.filter { $0.pathExtension == "mailsignature" }.map { $0.lastPathComponent }
    }
    
    func deleteSignatureFromMail(_ signatureId: UUID) throws {
        let signatureFileName = "\(signatureId.uuidString).mailsignature"
        let signatureFilePath = signaturesDirectory.appendingPathComponent(signatureFileName)
        
        if fileManager.fileExists(atPath: signatureFilePath.path) {
            try fileManager.removeItem(at: signatureFilePath)
        }
    }
    
    // MARK: - Validation
    
    func validateMailAccess() -> Bool {
        // Check if we have access to the Mail directory
        return fileManager.fileExists(atPath: mailDataDirectory.path) &&
               fileManager.isReadableFile(atPath: mailDataDirectory.path) &&
               fileManager.isWritableFile(atPath: mailDataDirectory.path)
    }
    
    func isMailRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == "com.apple.mail" }
    }
    
    func isMailInstalled() -> Bool {
        let mailAppPath = "/Applications/Mail.app"
        return fileManager.fileExists(atPath: mailAppPath)
    }
}

// MARK: - String Extensions

extension String {
    var xmlEscaped: String {
        return self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    var sha256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}