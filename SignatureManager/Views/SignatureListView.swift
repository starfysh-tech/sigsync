import SwiftUI

struct SignatureListView: View {
    @ObservedObject var storageService = SignatureStorageService.shared
    @Binding var selectedSignature: SignatureModel?
    
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
            if storageService.signatures.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "signature")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    
                    Text("No signatures yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Create your first email signature to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Create Sample Signature") {
                        createSampleSignature()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
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