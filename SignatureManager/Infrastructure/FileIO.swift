import Foundation

enum FileIOError: Error {
    case directoryCreationFailed
    case fileWriteFailed
    case fileReadFailed
    case backupFailed
    case invalidPath
}

class FileIO {
    static let shared = FileIO()
    
    private init() {}
    
    /// Base directory for SignatureManager data
    var baseDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SignatureManager")
    }
    
    /// Ensure the base directory structure exists
    func ensureDirectoryStructure() throws {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
        
        let signaturesDir = baseDirectory.appendingPathComponent("signatures")
        if !fileManager.fileExists(atPath: signaturesDir.path) {
            try fileManager.createDirectory(at: signaturesDir, withIntermediateDirectories: true)
        }
    }
    
    /// Atomic write with backup
    func writeData<T: Codable>(_ data: T, to url: URL, createBackup: Bool = true) throws {
        try ensureDirectoryStructure()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(data)
        
        // Create backup if file exists and backup is requested
        if createBackup && FileManager.default.fileExists(atPath: url.path) {
            let backupURL = url.appendingPathExtension("backup")
            try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: url, to: backupURL)
        }
        
        // Write to temporary file first
        let tempURL = url.appendingPathExtension("tmp")
        try jsonData.write(to: tempURL)
        
        // Atomic replace
        _ = try FileManager.default.replaceItem(at: url, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
    }
    
    /// Read and decode data
    func readData<T: Codable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    
    /// Check if file exists
    func fileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Delete file
    func deleteFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
    
    /// List files in directory
    func listFiles(in directory: URL, withExtension ext: String? = nil) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        
        if let ext = ext {
            return contents.filter { $0.pathExtension == ext }
        }
        
        return contents
    }
}