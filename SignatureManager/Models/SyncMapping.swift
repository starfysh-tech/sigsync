import Foundation

struct SyncState: Codable {
    struct AccountSyncRecord: Codable {
        var accountId: String
        var accountType: SignatureAccountBinding.AccountType
        var lastSyncTime: Date
        var lastRemoteHash: String?
        var hasConflict: Bool
        var conflictMessage: String?
    }
    
    var records: [String: AccountSyncRecord] // Key: account ID
    
    init() {
        self.records = [:]
    }
    
    mutating func updateSyncRecord(
        accountId: String,
        accountType: SignatureAccountBinding.AccountType,
        remoteHash: String? = nil,
        hasConflict: Bool = false,
        conflictMessage: String? = nil
    ) {
        records[accountId] = AccountSyncRecord(
            accountId: accountId,
            accountType: accountType,
            lastSyncTime: Date(),
            lastRemoteHash: remoteHash,
            hasConflict: hasConflict,
            conflictMessage: conflictMessage
        )
    }
    
    func getSyncRecord(for accountId: String) -> AccountSyncRecord? {
        return records[accountId]
    }
}