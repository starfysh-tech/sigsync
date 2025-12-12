import Foundation
import Combine

class SignatureStorageService: ObservableObject {
    static let shared = SignatureStorageService()
    
    @Published var signatures: [SignatureModel] = []
    @Published var mailAccountCache = MailAccountCache()
    @Published var gmailAccountCache = GmailAccountCache()
    @Published var syncState = SyncState()
    
    private let fileIO = FileIO.shared
    
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