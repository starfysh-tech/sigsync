import SwiftUI

struct SignatureEditorView: View {
    @Binding var signature: SignatureModel?
    @State private var htmlContent: String = ""
    @State private var signatureName: String = ""
    @State private var validationWarnings: [ValidationWarning] = []
    @State private var isDirty: Bool = false
    @State private var debounceTimer: Timer?
    
    private let storageService = SignatureStorageService.shared
    private let validationService = HTMLValidationService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with name field and save button
            HStack {
                TextField("Signature Name", text: $signatureName)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)
                    .onChange(of: signatureName) { _ in
                        markDirty()
                    }
                
                Spacer()
                
                if isDirty {
                    Button("Save") {
                        saveSignature()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut("s", modifiers: .command)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Validation warnings
            if !validationWarnings.isEmpty {
                ValidationWarningsView(warnings: validationWarnings)
                Divider()
            }
            
            // HTML Editor
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("HTML Content")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(htmlContent.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                TextEditor(text: $htmlContent)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: htmlContent) { _ in
                        markDirty()
                        scheduleValidation()
                    }
            }
            .padding()
        }
        .onAppear {
            loadSignature()
        }
        .onChange(of: signature) { _ in
            loadSignature()
        }
    }
    
    private func loadSignature() {
        guard let sig = signature else {
            htmlContent = ""
            signatureName = ""
            validationWarnings = []
            isDirty = false
            return
        }
        
        htmlContent = sig.htmlContent
        signatureName = sig.name
        isDirty = false
        validateHTML()
    }
    
    private func markDirty() {
        isDirty = true
    }
    
    private func scheduleValidation() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            validateHTML()
        }
    }
    
    private func validateHTML() {
        validationWarnings = validationService.validateHTML(htmlContent)
    }
    
    private func saveSignature() {
        guard var sig = signature else { return }
        
        sig.name = signatureName
        sig.htmlContent = htmlContent
        sig.updated = Date()
        
        do {
            try storageService.saveSignature(sig)
            signature = sig
            isDirty = false
        } catch {
            print("Failed to save signature: \(error)")
        }
    }
}

struct ValidationWarningsView: View {
    let warnings: [ValidationWarning]
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                    
                    Text("Validation Issues")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        if validationService.hasErrors(warnings) {
                            Label("\(warnings.filter { $0.severity == .error }.count)", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if validationService.hasWarnings(warnings) {
                            Label("\(warnings.filter { $0.severity == .warning }.count)", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        let infoCount = warnings.filter { $0.severity == .info }.count
                        if infoCount > 0 {
                            Label("\(infoCount)", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            
            // Warning list
            if isExpanded {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(warnings) { warning in
                            ValidationWarningRow(warning: warning)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
        }
    }
    
    private var validationService: HTMLValidationService {
        HTMLValidationService.shared
    }
}

struct ValidationWarningRow: View {
    let warning: ValidationWarning
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(warning.message)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Text(warning.category.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.02))
    }
    
    private var iconName: String {
        switch warning.severity {
        case .error: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }
    
    private var iconColor: Color {
        switch warning.severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

#Preview {
    SignatureEditorView(signature: .constant(SignatureStorageService.shared.createSampleSignature()))
}