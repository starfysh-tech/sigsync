import Foundation

struct SignatureAccountBinding: Codable, Identifiable {
    enum AccountType: String, Codable {
        case apple_mail
        case gmail
    }
    
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
    
    init(name: String, htmlContent: String) {
        self.id = UUID()
        self.name = name
        self.htmlContent = htmlContent
        self.created = Date()
        self.updated = Date()
        self.accounts = []
    }
}