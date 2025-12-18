import Foundation
import Combine

class SignatureStorageService: ObservableObject {
    static let shared = SignatureStorageService()
    
    @Published var signatures: [SignatureModel] = []
    @Published var mailAccountCache = MailAccountCache()
    @Published var gmailAccountCache = GmailAccountCache()
    @Published var syncState = SyncState()
    @Published var isPerformingInitialDiscovery = false
    @Published var lastDiscoveryError: String?
    @Published var discoveryCompletedSuccessfully = false
    
    private let fileIO = FileIO.shared
    private lazy var mailSyncService = MailSyncService.shared
    
    private var initialDiscoveryCompleted: Bool {
        UserDefaults.standard.bool(forKey: "initialDiscoveryCompleted")
    }
    
    private init() {
        loadAllData()
    }
    
    // MARK: - Signature Management
    
    func loadAllSignatures() {
        do {
            try fileIO.ensureDirectoryStructure()
            let signaturesDir = fileIO.baseDirectory.appendingPathComponent("signatures")
            let signatureFiles = try fileIO.listFiles(in: signaturesDir, withExtension: "json")
            
            var loadedSignatures: [SignatureModel] = []
            
            for file in signatureFiles {
                do {
                    let signature = try fileIO.readData(SignatureModel.self, from: file)
                    loadedSignatures.append(signature)
                } catch {
                    print("Failed to load signature from \(file.lastPathComponent): \(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.signatures = loadedSignatures.sorted { $0.updated > $1.updated }
            }
        } catch {
            print("Failed to load signatures: \(error)")
        }
    }
    
    func saveSignature(_ signature: SignatureModel) throws {
        let signaturesDir = fileIO.baseDirectory.appendingPathComponent("signatures")
        let fileURL = signaturesDir.appendingPathComponent("\(signature.id.uuidString).json")
        
        try fileIO.writeData(signature, to: fileURL)
        
        // Update in-memory collection
        DispatchQueue.main.async {
            if let index = self.signatures.firstIndex(where: { $0.id == signature.id }) {
                self.signatures[index] = signature
            } else {
                self.signatures.append(signature)
            }
            self.signatures.sort { $0.updated > $1.updated }
        }
    }
    
    func deleteSignature(_ signature: SignatureModel) throws {
        let signaturesDir = fileIO.baseDirectory.appendingPathComponent("signatures")
        let fileURL = signaturesDir.appendingPathComponent("\(signature.id.uuidString).json")
        
        try fileIO.deleteFile(at: fileURL)
        
        // Update in-memory collection
        DispatchQueue.main.async {
            self.signatures.removeAll { $0.id == signature.id }
        }
    }
    
    func getSignature(by id: UUID) -> SignatureModel? {
        return signatures.first { $0.id == id }
    }
    
    // MARK: - Account Cache Management
    
    func saveMailAccountCache() throws {
        let fileURL = fileIO.baseDirectory.appendingPathComponent("mail_accounts.json")
        try fileIO.writeData(mailAccountCache, to: fileURL)
    }
    
    func loadMailAccountCache() {
        let fileURL = fileIO.baseDirectory.appendingPathComponent("mail_accounts.json")
        
        do {
            let cache = try fileIO.readData(MailAccountCache.self, from: fileURL)
            DispatchQueue.main.async {
                self.mailAccountCache = cache
            }
        } catch {
            print("Failed to load mail account cache: \(error)")
            // Initialize with empty cache
            DispatchQueue.main.async {
                self.mailAccountCache = MailAccountCache()
            }
        }
    }
    
    func saveGmailAccountCache() throws {
        let fileURL = fileIO.baseDirectory.appendingPathComponent("gmail_accounts.json")
        try fileIO.writeData(gmailAccountCache, to: fileURL)
    }
    
    func loadGmailAccountCache() {
        let fileURL = fileIO.baseDirectory.appendingPathComponent("gmail_accounts.json")
        
        do {
            let cache = try fileIO.readData(GmailAccountCache.self, from: fileURL)
            DispatchQueue.main.async {
                self.gmailAccountCache = cache
            }
        } catch {
            print("Failed to load Gmail account cache: \(error)")
            // Initialize with empty cache
            DispatchQueue.main.async {
                self.gmailAccountCache = GmailAccountCache()
            }
        }
    }
    
    // MARK: - Sync State Management
    
    func saveSyncState() throws {
        let fileURL = fileIO.baseDirectory.appendingPathComponent("sync_state.json")
        try fileIO.writeData(syncState, to: fileURL)
    }
    
    func loadSyncState() {
        let fileURL = fileIO.baseDirectory.appendingPathComponent("sync_state.json")
        
        do {
            let state = try fileIO.readData(SyncState.self, from: fileURL)
            DispatchQueue.main.async {
                self.syncState = state
            }
        } catch {
            print("Failed to load sync state: \(error)")
            // Initialize with empty state
            DispatchQueue.main.async {
                self.syncState = SyncState()
            }
        }
    }
    
    func updateSyncRecord(
        for accountId: String,
        accountType: SignatureAccountBinding.AccountType,
        remoteHash: String? = nil,
        hasConflict: Bool = false,
        conflictMessage: String? = nil
    ) {
        syncState.updateSyncRecord(
            accountId: accountId,
            accountType: accountType,
            remoteHash: remoteHash,
            hasConflict: hasConflict,
            conflictMessage: conflictMessage
        )
        
        do {
            try saveSyncState()
        } catch {
            print("Failed to save sync state: \(error)")
        }
    }
    
    // MARK: - Initial Discovery
    
    func performInitialDiscoveryIfNeeded() async {
        await performDiscovery(force: false)
    }
    
    func performDiscovery(force: Bool) async {
        print("🔍 performDiscovery called (force: \(force))")
        print("   Current state:")
        print("     - signatures.count = \(signatures.count)")
        print("     - initialDiscoveryCompleted = \(initialDiscoveryCompleted)")
        print("     - isPerformingInitialDiscovery = \(isPerformingInitialDiscovery)")
        
        // Prevent multiple simultaneous discoveries
        if isPerformingInitialDiscovery && !force {
            print("   ⏭️  Skipping: discovery already in progress")
            return
        }
        
        // Skip if already completed (unless forced)
        if !force && initialDiscoveryCompleted {
            print("   ⏭️  Skipping: already completed (use force=true to retry)")
            return
        }
        
        // Also skip if signatures already exist (unless forced)
        if !force && !signatures.isEmpty {
            print("   ⏭️  Skipping: signatures already exist (\(signatures.count) signatures)")
            print("      Use force=true to import even with existing signatures")
            UserDefaults.standard.set(true, forKey: "initialDiscoveryCompleted")
            return
        }
        
        print("   ▶️  Starting discovery...")
        
        await MainActor.run {
            isPerformingInitialDiscovery = true
            lastDiscoveryError = nil
            discoveryCompletedSuccessfully = false
        }
        
        var importedCount = 0
        
        do {
            // Check permissions first
            let permissionStatus = mailSyncService.checkMailAccessPermission()
            guard permissionStatus.isAccessible else {
                throw NSError(
                    domain: "MailAccess",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: permissionStatus.userMessage]
                )
            }
            
            // Discover Mail accounts
            print("🔍 Discovering Mail accounts...")
            let accounts = try await mailSyncService.discoverMailAccounts()
            print("✅ Found \(accounts.count) Mail account(s)")
            
            // FIXED: Cache the discovered accounts
            await MainActor.run {
                var cache = self.mailAccountCache
                cache.mailAccounts = accounts
                self.mailAccountCache = cache
            }
            try saveMailAccountCache()
            
            // Import existing signatures
            print("🔍 Importing existing Mail signatures...")
            let importedSignatures = try await mailSyncService.importExistingSignatures()
            print("✅ Found \(importedSignatures.count) signature(s) in Mail.app")
            
            // Save imported signatures
            for signature in importedSignatures {
                do {
                    try saveSignature(signature)
                    importedCount += 1
                    print("   ✓ Imported: \(signature.name)")
                } catch {
                    print("   ✗ Failed to import \(signature.name): \(error)")
                }
            }
            
            if importedCount > 0 {
                print("🎉 Successfully imported \(importedCount) signature(s)!")
            } else {
                print("ℹ️ No signatures found to import")
            }
            
            // Mark discovery as successfully completed
            await MainActor.run {
                self.discoveryCompletedSuccessfully = true
            }
            
            // Mark discovery as complete
            UserDefaults.standard.set(true, forKey: "initialDiscoveryCompleted")
            
        } catch {
            let errorMessage: String
            let isPermissionError: Bool
            
            // Check if this is a permission error
            let nsError = error as NSError
            if nsError.domain == "MailAccess" || 
               error.localizedDescription.contains("Operation not permitted") ||
               error.localizedDescription.contains("Full Disk Access") {
                let status = mailSyncService.checkMailAccessPermission()
                errorMessage = status.userMessage
                isPermissionError = (status == .permissionDenied || status == .mailNotConfigured)
            } else {
                errorMessage = error.localizedDescription
                isPermissionError = false
            }
            
            await MainActor.run {
                self.lastDiscoveryError = errorMessage
            }
            
            print("⚠️ Initial discovery error: \(errorMessage)")
            print("   Is permission error: \(isPermissionError)")
            
            // FIXED: Don't mark as completed if permission denied
            // This allows retry when user grants permission
            if !isPermissionError {
                print("   ✅ Marking as completed (non-permission error, won't retry)")
                UserDefaults.standard.set(true, forKey: "initialDiscoveryCompleted")
            } else {
                print("   🔄 NOT marking as completed (permission error - will retry when granted)")
            }
        }
        
        await MainActor.run {
            isPerformingInitialDiscovery = false
        }
    }
    
    func resetInitialDiscovery() {
        UserDefaults.standard.set(false, forKey: "initialDiscoveryCompleted")
    }
    
    /// Check permission status at launch and retry discovery if permission was granted
    func checkPermissionAndRetryIfNeeded() async {
        print("🔐 Checking permission status at launch...")
        
        let permissionStatus = mailSyncService.checkMailAccessPermission()
        print("   Permission status: \(permissionStatus)")
        print("   initialDiscoveryCompleted: \(initialDiscoveryCompleted)")
        print("   signatures.count: \(signatures.count)")
        print("   lastDiscoveryError: \(lastDiscoveryError ?? "none")")
        
        // If permission is now granted but we had an error before, retry discovery
        if permissionStatus == .granted {
            // If we have an error OR (discovery not completed AND no signatures), try discovery
            let shouldRetry = (lastDiscoveryError != nil && !discoveryCompletedSuccessfully) ||
                              (!initialDiscoveryCompleted && signatures.isEmpty)
            
            if shouldRetry {
                print("   ✅ Permission granted and should retry - running discovery...")
                await performDiscovery(force: false)
            } else {
                print("   ℹ️  Permission granted but no retry needed")
                print("      - discoveryCompletedSuccessfully: \(discoveryCompletedSuccessfully)")
                print("      - initialDiscoveryCompleted: \(initialDiscoveryCompleted)")
            }
        } else {
            print("   ⏭️  Permission not granted, skipping check")
            print("      User needs to grant permission manually")
        }
    }
    
    // MARK: - Initialization
    
    private func loadAllData() {
        loadAllSignatures()
        loadMailAccountCache()
        loadGmailAccountCache()
        loadSyncState()
    }
    
    // MARK: - Utility
    
    func createSampleSignature() -> SignatureModel {
        let sampleHTML = """
        <div style="font-family: Arial, sans-serif; font-size: 14px; color: #333;">
            <p><strong>John Doe</strong><br>
            Software Engineer<br>
            Example Company</p>
            
            <p>📧 john.doe@example.com<br>
            📱 +1 (555) 123-4567<br>
            🌐 <a href="https://example.com">example.com</a></p>
        </div>
        """
        
        return SignatureModel(name: "Sample Signature", htmlContent: sampleHTML)
    }
}