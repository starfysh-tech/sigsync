import SwiftUI

struct SyncSettingsView: View {
    @Binding var selectedSignature: SignatureModel?
    @ObservedObject var storageService = SignatureStorageService.shared
    @State private var syncInProgress = false
    @State private var lastError: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Preview Section
            VStack(alignment: .leading, spacing: 8) {
                if let signature = selectedSignature {
                    SignaturePreviewContainer(htmlContent: signature.htmlContent)
                        .frame(height: 200)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 200)
                        .overlay(
                            Text("Select a signature to preview")
                                .foregroundColor(.secondary)
                        )
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Sync Settings
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Sync Settings")
                        .font(.headline)
                    
                    // Apple Mail Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text("Apple Mail")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        if storageService.mailAccountCache.mailAccounts.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No Mail accounts found")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                Button("Refresh Accounts") {
                                    // TODO: Refresh mail accounts
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(storageService.mailAccountCache.mailAccounts) { account in
                                    MailAccountRow(
                                        account: account,
                                        signature: selectedSignature,
                                        onSync: { syncToMail(account: account) }
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(8)
                    
                    // Gmail Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.red)
                            Text("Gmail")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        if storageService.gmailAccountCache.accounts.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No Gmail accounts connected")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                
                                Button("Connect Gmail") {
                                    // TODO: OAuth flow
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(storageService.gmailAccountCache.accounts) { account in
                                    GmailAccountRow(
                                        account: account,
                                        signature: selectedSignature,
                                        onSync: { syncToGmail(account: account) }
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(8)
                    
                    // Error Display
                    if let error = lastError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Sync Buttons
                    VStack(spacing: 8) {
                        Button("Sync to Apple Mail") {
                            syncAllToMail()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedSignature == nil || syncInProgress || storageService.mailAccountCache.mailAccounts.isEmpty)
                        
                        Button("Sync to Gmail") {
                            syncAllToGmail()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedSignature == nil || syncInProgress || storageService.gmailAccountCache.accounts.isEmpty)
                    }
                }
                .padding()
            }
        }
        .frame(width: 300)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func syncToMail(account: MailAccountCache.MailAccount) {
        // TODO: Implement Mail sync
        print("Syncing to Mail account: \(account.emailAddress)")
    }
    
    private func syncToGmail(account: GmailAccountCache.GmailAccount) {
        // TODO: Implement Gmail sync
        print("Syncing to Gmail account: \(account.emailAddress)")
    }
    
    private func syncAllToMail() {
        guard let signature = selectedSignature else { return }
        
        syncInProgress = true
        lastError = nil
        
        // TODO: Implement bulk Mail sync
        print("Syncing signature '\(signature.name)' to all Mail accounts")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            syncInProgress = false
        }
    }
    
    private func syncAllToGmail() {
        guard let signature = selectedSignature else { return }
        
        syncInProgress = true
        lastError = nil
        
        // TODO: Implement bulk Gmail sync
        print("Syncing signature '\(signature.name)' to all Gmail accounts")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            syncInProgress = false
        }
    }
}

struct MailAccountRow: View {
    let account: MailAccountCache.MailAccount
    let signature: SignatureModel?
    let onSync: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.accountName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(account.emailAddress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if account.isICloud {
                    Text("iCloud")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Button("Sync") {
                onSync()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(signature == nil)
        }
    }
}

struct GmailAccountRow: View {
    let account: GmailAccountCache.GmailAccount
    let signature: SignatureModel?
    let onSync: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(account.emailAddress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if account.isPrimary {
                    Text("Primary")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                if !account.aliases.isEmpty {
                    Text("\(account.aliases.count) aliases")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Sync") {
                onSync()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(signature == nil)
        }
    }
}

#Preview {
    SyncSettingsView(selectedSignature: .constant(SignatureStorageService.shared.createSampleSignature()))
}