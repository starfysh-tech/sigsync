import Foundation

struct MailAccountCache: Codable {
    struct MailAccount: Codable, Identifiable {
        var id: String          // Mail account UUID (AccountsMap key)
        var emailAddress: String
        var accountName: String
        var isICloud: Bool
        var lastRefresh: Date
    }
    
    var mailAccounts: [MailAccount]
    
    init() {
        self.mailAccounts = []
    }
}