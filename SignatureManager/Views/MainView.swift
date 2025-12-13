import SwiftUI

struct MainView: View {
    @State private var selectedSignature: SignatureModel?
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Signature List
            SignatureListView(selectedSignature: $selectedSignature)
            
            Divider()
            
            // Center: Editor
            SignatureEditorView(signature: $selectedSignature)
                .frame(minWidth: 400)
            
            Divider()
            
            // Right: Preview + Sync
            SyncSettingsView(selectedSignature: $selectedSignature)
        }
        .frame(minWidth: 950, minHeight: 600)
    }
}

#Preview {
    MainView()
}