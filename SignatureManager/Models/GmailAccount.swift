import Foundation

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
    
    init() {
        self.accounts = []
    }
}