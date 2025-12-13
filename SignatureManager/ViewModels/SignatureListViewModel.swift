import Foundation
import Combine

class SignatureListViewModel: ObservableObject {
    @Published var signatures: [SignatureModel] = []
    @Published var selectedSignature: SignatureModel?
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let storageService = SignatureStorageService.shared
    private var cancellables = Set<AnyCancellable>()
    
    var filteredSignatures: [SignatureModel] {
        if searchText.isEmpty {
            return signatures
        }
        return signatures.filter { signature in
            signature.name.localizedCaseInsensitiveContains(searchText) ||
            signature.htmlContent.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    init() {
        setupBindings()
        loadSignatures()
    }
    
    private func setupBindings() {
        // Observe storage service signatures
        storageService.$signatures
            .receive(on: DispatchQueue.main)
            .assign(to: \.signatures, on: self)
            .store(in: &cancellables)
    }
    
    func loadSignatures() {
        isLoading = true
        errorMessage = nil
        
        storageService.loadAllSignatures()
        
        // Simulate loading delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isLoading = false
        }
    }
    
    func createNewSignature() {
        let newSignature = SignatureModel(
            name: "New Signature",
            htmlContent: "<p>Your signature here...</p>"
        )
        
        do {
            try storageService.saveSignature(newSignature)
            selectedSignature = newSignature
        } catch {
            errorMessage = "Failed to create signature: \(error.localizedDescription)"
        }
    }
    
    func createSampleSignature() {
        let sampleSignature = storageService.createSampleSignature()
        
        do {
            try storageService.saveSignature(sampleSignature)
            selectedSignature = sampleSignature
        } catch {
            errorMessage = "Failed to create sample signature: \(error.localizedDescription)"
        }
    }
    
    func deleteSignature(_ signature: SignatureModel) {
        do {
            try storageService.deleteSignature(signature)
            
            // Update selection if deleted signature was selected
            if selectedSignature?.id == signature.id {
                selectedSignature = signatures.first
            }
        } catch {
            errorMessage = "Failed to delete signature: \(error.localizedDescription)"
        }
    }
    
    func duplicateSignature(_ signature: SignatureModel) {
        var duplicatedSignature = signature
        duplicatedSignature.id = UUID()
        duplicatedSignature.name = "\(signature.name) Copy"
        duplicatedSignature.created = Date()
        duplicatedSignature.updated = Date()
        
        do {
            try storageService.saveSignature(duplicatedSignature)
            selectedSignature = duplicatedSignature
        } catch {
            errorMessage = "Failed to duplicate signature: \(error.localizedDescription)"
        }
    }
    
    func selectSignature(_ signature: SignatureModel) {
        selectedSignature = signature
    }
    
    func clearError() {
        errorMessage = nil
    }
}