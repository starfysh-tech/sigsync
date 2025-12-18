import SwiftUI

@main
struct SignatureManagerApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        // FDA Debug window - open with Window > FDA Debug Tool or Cmd+Option+D
        Window("FDA Debug Tool", id: "debug-window") {
            DebugView()
        }
        .keyboardShortcut("d", modifiers: [.command, .option])
        .defaultPosition(.center)
    }
}

// MARK: - FDA Debug View

struct DebugView: View {
    @State private var testResult: String = ""
    @State private var testing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FDA Debug Tool")
                .font(.title)
            
            Text("Use this tool to verify Full Disk Access is working")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current App Path:")
                    .font(.headline)
                Text(Bundle.main.bundleURL.path)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Divider()
            
            Button(testing ? "Testing..." : "Test Full Disk Access") {
                runTest()
            }
            .disabled(testing)
            .buttonStyle(.borderedProminent)
            
            if !testResult.isEmpty {
                Divider()
                
                Text("Test Result:")
                    .font(.headline)
                
                ScrollView {
                    Text(testResult)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(4)
                }
                .frame(maxHeight: 300)
            }
            
            Divider()
            
            Text("Quick Actions:")
                .font(.headline)
            
            HStack {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                Button("Show App in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }
                
                Button("Copy App Path") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(Bundle.main.bundleURL.path, forType: .string)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 700, height: 600)
    }
    
    private func runTest() {
        testing = true
        testResult = ""
        
        Task {
            let result = await performFDATest()
            await MainActor.run {
                testResult = result
                testing = false
            }
        }
    }
    
    private func performFDATest() async -> String {
        var log = "🔍 Full Disk Access Test\n"
        log += String(repeating: "=", count: 60) + "\n\n"
        
        let fm = FileManager.default
        let mailBaseDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mail")
        
        // Detect Mail version
        var mailDir: URL?
        var detectedVersion: Int?
        for version in (8...12).reversed() {
            let versionedPath = mailBaseDir.appendingPathComponent("V\(version)/MailData")
            if fm.fileExists(atPath: versionedPath.path) {
                mailDir = versionedPath
                detectedVersion = version
                break
            }
        }
        
        if mailDir == nil {
            mailDir = mailBaseDir.appendingPathComponent("V10/MailData")
        }
        
        log += "1. Mail Directory Check\n"
        if let version = detectedVersion {
            log += "   Detected Mail Version: V\(version)\n"
        } else {
            log += "   No Mail version detected, checking V10\n"
        }
        log += "   Path: \(mailDir!.path)\n"
        log += "   Exists: \(fm.fileExists(atPath: mailDir!.path) ? "✅ Yes" : "❌ No")\n\n"
        
        guard fm.fileExists(atPath: mailDir!.path) else {
            log += "❌ Mail.app is not configured\n\n"
            log += "To fix:\n"
            log += "1. Open the Mail app\n"
            log += "2. Add at least one email account\n"
            log += "3. Create at least one signature\n"
            log += "4. Return here and test again\n"
            return log
        }
        
        log += "2. TCC Permission Test (The Real Check)\n"
        do {
            let contents = try fm.contentsOfDirectory(atPath: mailDir!.path)
            log += "   ✅ SUCCESS - Full Disk Access is WORKING!\n"
            log += "   Read \(contents.count) items from Mail directory\n"
            log += "   Contents: \(contents.sorted().joined(separator: ", "))\n\n"
            
            log += "3. Mail Data Verification\n"
            
            // Check Accounts
            if contents.contains("Accounts") {
                let accountsDir = mailDir!.appendingPathComponent("Accounts")
                if let accountItems = try? fm.contentsOfDirectory(atPath: accountsDir.path) {
                    let plists = accountItems.filter { $0.hasSuffix(".plist") }
                    log += "   ✅ Accounts: Found \(plists.count) account file(s)\n"
                } else {
                    log += "   ⚠️  Accounts directory exists but can't read it\n"
                }
            } else {
                log += "   ⚠️  Accounts directory not found\n"
            }
            
            // Check Signatures
            if contents.contains("Signatures") {
                let signaturesDir = mailDir!.appendingPathComponent("Signatures")
                if let sigItems = try? fm.contentsOfDirectory(atPath: signaturesDir.path) {
                    let sigs = sigItems.filter { $0.hasSuffix(".mailsignature") }
                    log += "   ✅ Signatures: Found \(sigs.count) signature file(s)\n"
                } else {
                    log += "   ⚠️  Signatures directory exists but can't read it\n"
                }
            } else {
                log += "   ⚠️  Signatures directory not found\n"
            }
            
            log += "\n" + String(repeating: "=", count: 60) + "\n"
            log += "✅ RESULT: Full Disk Access is properly configured!\n"
            log += String(repeating: "=", count: 60) + "\n"
            
        } catch let error as NSError {
            log += "   ❌ FAILED - Cannot read Mail directory\n"
            log += "   Error: \(error.localizedDescription)\n"
            log += "   Domain: \(error.domain)\n"
            log += "   Code: \(error.code)\n\n"
            
            log += String(repeating: "=", count: 60) + "\n"
            log += "❌ RESULT: Full Disk Access is NOT working\n"
            log += String(repeating: "=", count: 60) + "\n\n"
            
            log += "How to fix:\n\n"
            log += "1. Click 'Open System Settings' above\n\n"
            log += "2. Navigate to:\n"
            log += "   Privacy & Security > Full Disk Access\n\n"
            log += "3. Click the 🔒 lock icon (bottom left)\n"
            log += "   Enter your password\n\n"
            log += "4. Remove any old 'SignatureManager' entries:\n"
            log += "   Select them and click the - button\n\n"
            log += "5. Click the + button and add THIS app:\n"
            log += "   \(Bundle.main.bundleURL.path)\n"
            log += "   (Use 'Copy App Path' button above, then Cmd+Shift+G to paste)\n\n"
            log += "6. Make sure the toggle is ON (blue checkmark)\n\n"
            log += "7. Close System Settings\n\n"
            log += "8. Quit and restart this app\n\n"
            log += "9. Run this test again\n\n"
            
            log += "Note: If the toggle shows ON but access still fails:\n"
            log += "• TCC cache may be stale - restart your Mac\n"
            log += "• Or different app version was granted permission\n"
        }
        
        return log
    }
}