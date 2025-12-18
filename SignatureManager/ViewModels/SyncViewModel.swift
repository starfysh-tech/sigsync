import Foundation
import Combine
import CryptoKit

class SyncViewModel: ObservableObject {
    @Published var isMailSyncInProgress: Bool = false
    @Published var isGmailSyncInProgress: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncErrors: [SyncError] = []
    @Published var mailAccounts: [MailAccountCache.MailAccount] = []
    @Published var gmailAccounts: [GmailAccountCache.GmailAccount] = []
    @Published var syncProgress: SyncProgress = SyncProgress()
    
    private let storageService = SignatureStorageService.shared
    private var cancellables = Set<AnyCancellable>()
    
    var canSyncToMail: Bool {
        !mailAccounts.isEmpty && !isMailSyncInProgress
    }
    
    var canSyncToGmail: Bool {
        !gmailAccounts.isEmpty && !isGmailSyncInProgress
    }
    
    var hasActiveSyncs: Bool {
        isMailSyncInProgress || isGmailSyncInProgress
    }
    
    init() {
        setupBindings()
        loadAccountData()
    }
    
    private func setupBindings() {
        // Observe account changes from storage service
        storageService.$mailAccountCache
            .map(\.mailAccounts)
            .receive(on: DispatchQueue.main)
            .assign(to: \.mailAccounts, on: self)
            .store(in: &cancellables)
        
        storageService.$gmailAccountCache
            .map(\.accounts)
            .receive(on: DispatchQueue.main)
            .assign(to: \.gmailAccounts, on: self)
            .store(in: &cancellables)
    }
    
    private func loadAccountData() {
        storageService.loadMailAccountCache()
        storageService.loadGmailAccountCache()
    }
    
    // MARK: - Mail Sync
    
    func syncSignatureToMail(_ signature: SignatureModel, accounts: [MailAccountCache.MailAccount]? = nil) {
        let targetAccounts = accounts ?? mailAccounts
        
        guard !targetAccounts.isEmpty else {
            addSyncError(.noAccountsFound(service: "Apple Mail"))
            return
        }
        
        isMailSyncInProgress = true
        syncProgress.reset()
        syncProgress.totalSteps = targetAccounts.count
        
        Task {
            for account in targetAccounts {
                await syncToSingleMailAccount(signature, account: account)
                await MainActor.run {
                    syncProgress.completedSteps += 1
                }
            }
            
            await MainActor.run {
                isMailSyncInProgress = false
                lastSyncDate = Date()
            }
        }
    }
    
    private func syncToSingleMailAccount(_ signature: SignatureModel, account: MailAccountCache.MailAccount) async {
        do {
            // TODO: Implement actual Mail sync via MailSyncService
            // For now, simulate the sync process
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            
            await MainActor.run {
                // Update sync mapping
                storageService.updateSyncRecord(
                    for: account.id,
                    accountType: .apple_mail,
                    remoteHash: signature.htmlContent.sha256
                )
            }
            
            print("Synced signature '\(signature.name)' to Mail account: \(account.emailAddress)")
            
        } catch {
            await MainActor.run {
                addSyncError(.syncFailed(service: "Apple Mail", account: account.emailAddress, error: error))
            }
        }
    }
    
    // MARK: - Gmail Sync
    
    func syncSignatureToGmail(_ signature: SignatureModel, accounts: [GmailAccountCache.GmailAccount]? = nil) {
        let targetAccounts = accounts ?? gmailAccounts
        
        guard !targetAccounts.isEmpty else {
            addSyncError(.noAccountsFound(service: "Gmail"))
            return
        }
        
        isGmailSyncInProgress = true
        syncProgress.reset()
        syncProgress.totalSteps = targetAccounts.count
        
        Task {
            for account in targetAccounts {
                await syncToSingleGmailAccount(signature, account: account)
                await MainActor.run {
                    syncProgress.completedSteps += 1
                }
            }
            
            await MainActor.run {
                isGmailSyncInProgress = false
                lastSyncDate = Date()
            }
        }
    }
    
    private func syncToSingleGmailAccount(_ signature: SignatureModel, account: GmailAccountCache.GmailAccount) async {
        do {
            // TODO: Implement actual Gmail sync via GmailService
            // For now, simulate the sync process
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 second delay
            
            await MainActor.run {
                // Update sync mapping
                storageService.updateSyncRecord(
                    for: account.id,
                    accountType: .gmail,
                    remoteHash: signature.htmlContent.sha256
                )
            }
            
            print("Synced signature '\(signature.name)' to Gmail account: \(account.emailAddress)")
            
        } catch {
            await MainActor.run {
                addSyncError(.syncFailed(service: "Gmail", account: account.emailAddress, error: error))
            }
        }
    }
    
    // MARK: - Bulk Sync
    
    func syncToAllServices(_ signature: SignatureModel) {
        syncSignatureToMail(signature)
        syncSignatureToGmail(signature)
    }
    
    // MARK: - Account Management
    
    func refreshMailAccounts() {
        // TODO: Implement Mail account discovery
        print("Refreshing Mail accounts...")
    }
    
    func connectGmailAccount() {
        // TODO: Implement Gmail OAuth flow
        print("Starting Gmail OAuth flow...")
    }
    
    func disconnectGmailAccount(_ account: GmailAccountCache.GmailAccount) {
        // TODO: Implement Gmail account disconnection
        print("Disconnecting Gmail account: \(account.emailAddress)")
    }
    
    // MARK: - Error Management
    
    private func addSyncError(_ error: SyncError) {
        syncErrors.append(error)
        
        // Auto-remove errors after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.syncErrors.removeAll { $0.id == error.id }
        }
    }
    
    func clearSyncError(_ error: SyncError) {
        syncErrors.removeAll { $0.id == error.id }
    }
    
    func clearAllSyncErrors() {
        syncErrors.removeAll()
    }
}

// MARK: - Supporting Types

struct SyncProgress {
    var completedSteps: Int = 0
    var totalSteps: Int = 0
    
    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(completedSteps) / Double(totalSteps)
    }
    
    var isComplete: Bool {
        completedSteps >= totalSteps && totalSteps > 0
    }
    
    mutating func reset() {
        completedSteps = 0
        totalSteps = 0
    }
}

struct SyncError: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let service: String
    let account: String?
    let timestamp: Date = Date()
    
    static func noAccountsFound(service: String) -> SyncError {
        SyncError(
            message: "No \(service) accounts found. Please configure accounts first.",
            service: service,
            account: nil
        )
    }
    
    static func syncFailed(service: String, account: String, error: Error) -> SyncError {
        SyncError(
            message: "Failed to sync to \(service): \(error.localizedDescription)",
            service: service,
            account: account
        )
    }
    
    static func == (lhs: SyncError, rhs: SyncError) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - String Extension for SHA256

extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}