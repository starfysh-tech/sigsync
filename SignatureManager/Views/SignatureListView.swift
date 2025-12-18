import SwiftUI
import AppKit

struct SignatureListView: View {
    @ObservedObject var storageService = SignatureStorageService.shared
    @Binding var selectedSignature: SignatureModel?
    @State private var hasTriggeredDiscovery = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Signatures")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: createNewSignature) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Create new signature")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Signature List
            if storageService.isPerformingInitialDiscovery {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Discovering email accounts...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Looking for existing signatures in Mail.app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if storageService.signatures.isEmpty {
                VStack(spacing: 16) {
                    // Show error if discovery failed
                    if let error = storageService.lastDiscoveryError {
                        ScrollView {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.orange)
                                
                                Text("Setup Required")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal)
                                    .textSelection(.enabled)
                                
                                if error.contains("Full Disk Access") {
                                    VStack(spacing: 8) {
                                        Button("Open System Settings") {
                                            openSystemSettings()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        
                                        HStack(spacing: 8) {
                                            Button("Show App in Finder") {
                                                showAppInFinder()
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            
                                            Button("Copy Path") {
                                                copyAppPath()
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        }
                                        
                                        Text("After granting access, click Retry")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Button("Retry Discovery") {
                                    retryDiscovery()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Divider()
                                    .padding(.vertical, 4)
                                
                                Text("Or skip discovery and create manually:")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Button("Create Signature Manually") {
                                    createSampleSignature()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding()
                        }
                    } else if storageService.discoveryCompletedSuccessfully {
                        // Discovery completed successfully but found nothing
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 32))
                                .foregroundColor(.green)
                            
                            Text("No Signatures Found")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Checked Mail.app but didn't find any existing signatures")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                Button("Create Sample Signature") {
                                    createSampleSignature()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                Button("Create Blank Signature") {
                                    createNewSignature()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    } else {
                        // Discovery hasn't run yet or status unknown
                        VStack(spacing: 12) {
                            Image(systemName: "signature")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary)
                            
                            Text("No signatures yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Create your first signature")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Button("Create Sample Signature") {
                                    createSampleSignature()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                
                                Button("Search for Existing") {
                                    retryDiscovery()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(storageService.signatures) { signature in
                            SignatureRowView(
                                signature: signature,
                                isSelected: selectedSignature?.id == signature.id,
                                onSelect: { selectedSignature = signature },
                                onDelete: { deleteSignature(signature) }
                            )
                        }
                    }
                }
            }
        }
        .frame(width: 250)
        .background(Color(NSColor.controlBackgroundColor))
        .task {
            // Check permission and run discovery on first appearance
            if !hasTriggeredDiscovery {
                hasTriggeredDiscovery = true
                
                // Debug: Write to file so we know this is being called
                let debugMsg = "📱 SignatureListView.task called at \(Date())\n"
                try? debugMsg.write(toFile: "/tmp/sigsync_task_debug.txt", atomically: true, encoding: .utf8)
                
                print("📱 App launched - checking permissions and running discovery...")
                
                // Check if permission was granted since last launch
                await storageService.checkPermissionAndRetryIfNeeded()
                
                // Then run normal initial discovery if needed
                await storageService.performInitialDiscoveryIfNeeded()
            }
        }
    }
    
    private func createNewSignature() {
        let newSignature = SignatureModel(name: "New Signature", htmlContent: "<p>Your signature here...</p>")
        
        do {
            try storageService.saveSignature(newSignature)
            selectedSignature = newSignature
        } catch {
            print("Failed to create new signature: \(error)")
        }
    }
    
    private func createSampleSignature() {
        let sampleSignature = storageService.createSampleSignature()
        
        do {
            try storageService.saveSignature(sampleSignature)
            selectedSignature = sampleSignature
        } catch {
            print("Failed to create sample signature: \(error)")
        }
    }
    
    private func deleteSignature(_ signature: SignatureModel) {
        do {
            try storageService.deleteSignature(signature)
            if selectedSignature?.id == signature.id {
                selectedSignature = storageService.signatures.first
            }
        } catch {
            print("Failed to delete signature: \(error)")
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func copyAppPath() {
        let path = Bundle.main.bundleURL.path
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        print("📋 Copied app path to clipboard: \(path)")
    }
    
    private func showAppInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
        print("📂 Showing app in Finder: \(Bundle.main.bundleURL.path)")
    }
    
    private func retryDiscovery() {
        Task {
            print("🔄 User triggered retry discovery")
            hasTriggeredDiscovery = false
            storageService.resetInitialDiscovery()
            // Use force=true to run discovery even if signatures already exist
            await storageService.performDiscovery(force: true)
            print("✅ Retry discovery completed")
        }
    }
}

struct SignatureRowView: View {
    let signature: SignatureModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(signature.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text("Updated \(signature.updated, style: .relative)")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                
                if !signature.accounts.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(signature.accounts.prefix(3), id: \.id) { account in
                            Image(systemName: account.type == .apple_mail ? "envelope" : "globe")
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        }
                        
                        if signature.accounts.count > 3 {
                            Text("+\(signature.accounts.count - 3)")
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete signature")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    SignatureListView(selectedSignature: .constant(nil))
}