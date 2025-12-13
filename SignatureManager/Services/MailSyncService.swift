import Foundation
import OSAKit

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
    private let storageService = SignatureStorageService.shared
    
    private init() {}
    
    // MARK: - Mail Directory Paths
    
    private var mailDataDirectory: URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent("Library/Mail/V10/MailData")
    }
    
    private var signaturesDirectory: URL {
        mailDataDirectory.appendingPathComponent("Signatures")
    }
    
    private var accountsDirectory: URL {
        mailDataDirectory.appendingPathComponent("Accounts")
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
        
        // Update cache
        var cache = storageService.mailAccountCache
        cache.mailAccounts = accounts
        cache.lastUpdated = Date()
        
        await MainActor.run {
            storageService.mailAccountCache = cache
        }
        
        try storageService.saveMailAccountCache()
        
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
        
        guard let appleScript = OSAScript(source: script) else {
            throw MailSyncError.accountDiscoveryFailed
        }
        
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        
        if let error = error {
            print("AppleScript error: \(error)")
            throw MailSyncError.accountDiscoveryFailed
        }
        
        return parseAppleScriptAccountResult(result)
    }
    
    private func parseAppleScriptAccountResult(_ result: OSAScriptResult) -> [MailAccountCache.MailAccount] {
        // Parse the AppleScript result and convert to MailAccount objects
        // This is a simplified implementation
        var accounts: [MailAccountCache.MailAccount] = []
        
        // For demo purposes, create sample accounts
        accounts.append(MailAccountCache.MailAccount(
            id: UUID().uuidString,
            accountName: "iCloud",
            emailAddress: "user@icloud.com",
            isICloud: true
        ))
        
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
        // Parse account information from directory structure
        // This is a simplified implementation
        let accountName = directory.lastPathComponent
        
        return MailAccountCache.MailAccount(
            id: accountName,
            accountName: accountName,
            emailAddress: "\(accountName)@example.com",
            isICloud: accountName.contains("iCloud")
        )
    }
    
    // MARK: - Signature Sync
    
    func syncSignatureToMail(_ signature: SignatureModel, account: MailAccountCache.MailAccount) async throws {
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
}