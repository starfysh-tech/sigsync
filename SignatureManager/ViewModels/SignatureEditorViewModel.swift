import Foundation
import Combine

class SignatureEditorViewModel: ObservableObject {
    @Published var signature: SignatureModel?
    @Published var htmlContent: String = ""
    @Published var signatureName: String = ""
    @Published var validationWarnings: [ValidationWarning] = []
    @Published var isDirty: Bool = false
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?
    @Published var lastSaved: Date?
    
    private let storageService = SignatureStorageService.shared
    private let validationService = HTMLValidationService.shared
    private var cancellables = Set<AnyCancellable>()
    private var debounceTimer: Timer?
    
    var hasErrors: Bool {
        validationService.hasErrors(validationWarnings)
    }
    
    var hasWarnings: Bool {
        validationService.hasWarnings(validationWarnings)
    }
    
    var characterCount: Int {
        htmlContent.count
    }
    
    var wordCount: Int {
        let words = htmlContent.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Debounced validation
        $htmlContent
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.validateHTML()
            }
            .store(in: &cancellables)
        
        // Mark as dirty when content changes
        Publishers.CombineLatest($htmlContent, $signatureName)
            .dropFirst() // Skip initial values
            .sink { [weak self] _, _ in
                self?.markDirty()
            }
            .store(in: &cancellables)
    }
    
    func loadSignature(_ newSignature: SignatureModel?) {
        guard let sig = newSignature else {
            clearEditor()
            return
        }
        
        signature = sig
        htmlContent = sig.htmlContent
        signatureName = sig.name
        isDirty = false
        lastSaved = sig.updated
        validateHTML()
    }
    
    private func clearEditor() {
        signature = nil
        htmlContent = ""
        signatureName = ""
        validationWarnings = []
        isDirty = false
        lastSaved = nil
        errorMessage = nil
    }
    
    private func markDirty() {
        isDirty = true
    }
    
    private func validateHTML() {
        validationWarnings = validationService.validateHTML(htmlContent)
    }
    
    func saveSignature() {
        guard var sig = signature else {
            createNewSignature()
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        sig.name = signatureName.trimmingCharacters(in: .whitespacesAndNewlines)
        sig.htmlContent = htmlContent
        sig.updated = Date()
        
        // Validate name
        if sig.name.isEmpty {
            sig.name = "Untitled Signature"
        }
        
        do {
            try storageService.saveSignature(sig)
            signature = sig
            isDirty = false
            lastSaved = sig.updated
        } catch {
            errorMessage = "Failed to save signature: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
    
    private func createNewSignature() {
        let newSignature = SignatureModel(
            name: signatureName.isEmpty ? "New Signature" : signatureName,
            htmlContent: htmlContent
        )
        
        isSaving = true
        errorMessage = nil
        
        do {
            try storageService.saveSignature(newSignature)
            signature = newSignature
            isDirty = false
            lastSaved = newSignature.updated
        } catch {
            errorMessage = "Failed to create signature: \(error.localizedDescription)"
        }
        
        isSaving = false
    }
    
    func insertTemplate(_ template: HTMLTemplate) {
        let insertionPoint = htmlContent.isEmpty ? 0 : htmlContent.count
        let templateHTML = template.htmlContent
        
        if htmlContent.isEmpty {
            htmlContent = templateHTML
        } else {
            let index = htmlContent.index(htmlContent.startIndex, offsetBy: insertionPoint)
            htmlContent.insert(contentsOf: "\n\n\(templateHTML)", at: index)
        }
    }
    
    func formatSelection(with tag: String) {
        // For now, just append the tag - in a real implementation,
        // you'd want to track text selection in the editor
        htmlContent += "<\(tag)></\(tag)>"
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    deinit {
        debounceTimer?.invalidate()
    }
}

// MARK: - HTML Templates

enum HTMLTemplate: String, CaseIterable {
    case basic = "basic"
    case professional = "professional"
    case modern = "modern"
    case minimal = "minimal"
    
    var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .professional: return "Professional"
        case .modern: return "Modern"
        case .minimal: return "Minimal"
        }
    }
    
    var htmlContent: String {
        switch self {
        case .basic:
            return """
            <div style="font-family: Arial, sans-serif; font-size: 14px; color: #333;">
                <p><strong>[Your Name]</strong><br>
                [Your Title]<br>
                [Company Name]</p>
                
                <p>📧 [email@example.com]<br>
                📱 [phone number]</p>
            </div>
            """
            
        case .professional:
            return """
            <table style="font-family: Arial, sans-serif; font-size: 14px; color: #333; border-collapse: collapse;">
                <tr>
                    <td style="padding-right: 20px; vertical-align: top;">
                        <strong style="font-size: 16px; color: #2c3e50;">[Your Name]</strong><br>
                        <span style="color: #7f8c8d;">[Your Title]</span><br>
                        <span style="color: #2c3e50;">[Company Name]</span>
                    </td>
                </tr>
                <tr>
                    <td style="padding-top: 10px;">
                        <span style="color: #3498db;">📧</span> <a href="mailto:[email]" style="color: #3498db; text-decoration: none;">[email@example.com]</a><br>
                        <span style="color: #3498db;">📱</span> [phone number]<br>
                        <span style="color: #3498db;">🌐</span> <a href="[website]" style="color: #3498db; text-decoration: none;">[website]</a>
                    </td>
                </tr>
            </table>
            """
            
        case .modern:
            return """
            <div style="font-family: 'Helvetica Neue', Arial, sans-serif; font-size: 14px; color: #2c3e50; line-height: 1.6;">
                <div style="border-left: 4px solid #3498db; padding-left: 15px; margin-bottom: 15px;">
                    <h3 style="margin: 0; font-size: 18px; font-weight: 300; color: #2c3e50;">[Your Name]</h3>
                    <p style="margin: 5px 0; font-size: 13px; color: #7f8c8d;">[Your Title] at [Company Name]</p>
                </div>
                
                <div style="font-size: 13px;">
                    <p style="margin: 3px 0;"><span style="color: #3498db;">✉</span> [email@example.com]</p>
                    <p style="margin: 3px 0;"><span style="color: #3498db;">📞</span> [phone number]</p>
                    <p style="margin: 3px 0;"><span style="color: #3498db;">🔗</span> <a href="[website]" style="color: #3498db; text-decoration: none;">[website]</a></p>
                </div>
            </div>
            """
            
        case .minimal:
            return """
            <div style="font-family: 'SF Pro Text', -apple-system, BlinkMacSystemFont, sans-serif; font-size: 13px; color: #333; line-height: 1.4;">
                <p style="margin: 0;"><strong>[Your Name]</strong></p>
                <p style="margin: 2px 0; color: #666;">[email@example.com] • [phone number]</p>
            </div>
            """
        }
    }
}