import Foundation

struct ValidationWarning: Identifiable, Codable {
    let id = UUID()
    let message: String
    let severity: Severity
    let category: Category
    
    enum Severity: String, Codable, CaseIterable {
        case info = "info"
        case warning = "warning"
        case error = "error"
        
        var displayName: String {
            switch self {
            case .info: return "Info"
            case .warning: return "Warning"
            case .error: return "Error"
            }
        }
    }
    
    enum Category: String, Codable, CaseIterable {
        case security = "security"
        case compatibility = "compatibility"
        case performance = "performance"
        case style = "style"
        
        var displayName: String {
            switch self {
            case .security: return "Security"
            case .compatibility: return "Compatibility"
            case .performance: return "Performance"
            case .style: return "Style"
            }
        }
    }
}

class HTMLValidationService {
    static let shared = HTMLValidationService()
    
    private init() {}
    
    // MARK: - Main Validation
    
    func validateHTML(_ htmlContent: String) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        
        warnings.append(contentsOf: checkUnsafeTags(htmlContent))
        warnings.append(contentsOf: checkUnsafeAttributes(htmlContent))
        warnings.append(contentsOf: checkBase64Images(htmlContent))
        warnings.append(contentsOf: checkMediaQueries(htmlContent))
        warnings.append(contentsOf: checkContentSize(htmlContent))
        warnings.append(contentsOf: checkEmailCompatibility(htmlContent))
        
        return warnings
    }
    
    // MARK: - Security Checks
    
    private func checkUnsafeTags(_ html: String) -> [ValidationWarning] {
        let unsafeTags = ["script", "iframe", "object", "embed", "form", "input", "button", "link"]
        var warnings: [ValidationWarning] = []
        
        for tag in unsafeTags {
            let pattern = "<\\s*\(tag)\\b[^>]*>"
            if html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                warnings.append(ValidationWarning(
                    message: "Unsafe tag '<\(tag)>' detected. This may be stripped by email clients.",
                    severity: .error,
                    category: .security
                ))
            }
        }
        
        return warnings
    }
    
    private func checkUnsafeAttributes(_ html: String) -> [ValidationWarning] {
        let unsafeAttributes = ["onclick", "onload", "onerror", "onmouseover", "onmouseout", "onfocus", "onblur"]
        var warnings: [ValidationWarning] = []
        
        for attribute in unsafeAttributes {
            let pattern = "\\b\(attribute)\\s*="
            if html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                warnings.append(ValidationWarning(
                    message: "Unsafe attribute '\(attribute)' detected. JavaScript events are not supported in email signatures.",
                    severity: .error,
                    category: .security
                ))
            }
        }
        
        return warnings
    }
    
    // MARK: - Compatibility Checks
    
    private func checkBase64Images(_ html: String) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        
        let base64Pattern = "data:image/[^;]+;base64,"
        if html.range(of: base64Pattern, options: .regularExpression) != nil {
            warnings.append(ValidationWarning(
                message: "Base64 inline images detected. These work in Apple Mail but are stripped by Gmail.",
                severity: .warning,
                category: .compatibility
            ))
        }
        
        return warnings
    }
    
    private func checkMediaQueries(_ html: String) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        
        let mediaQueryPattern = "@media\\s*\\([^)]+\\)"
        if html.range(of: mediaQueryPattern, options: .regularExpression) != nil {
            warnings.append(ValidationWarning(
                message: "CSS media queries detected. These are ignored in Gmail but work in Apple Mail.",
                severity: .info,
                category: .compatibility
            ))
        }
        
        return warnings
    }
    
    private func checkEmailCompatibility(_ html: String) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        
        // Check for CSS properties that don't work well in email
        let problematicCSS = [
            ("position\\s*:\\s*fixed", "position: fixed"),
            ("position\\s*:\\s*absolute", "position: absolute"),
            ("float\\s*:", "float"),
            ("display\\s*:\\s*flex", "display: flex"),
            ("display\\s*:\\s*grid", "display: grid")
        ]
        
        for (pattern, property) in problematicCSS {
            if html.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                warnings.append(ValidationWarning(
                    message: "CSS property '\(property)' has limited support in email clients.",
                    severity: .warning,
                    category: .compatibility
                ))
            }
        }
        
        // Check for external resources
        let externalResourcePattern = "(src|href)\\s*=\\s*[\"']https?://"
        if html.range(of: externalResourcePattern, options: .regularExpression) != nil {
            warnings.append(ValidationWarning(
                message: "External resources (images, stylesheets) may be blocked by email clients for security.",
                severity: .info,
                category: .compatibility
            ))
        }
        
        return warnings
    }
    
    // MARK: - Performance Checks
    
    private func checkContentSize(_ html: String) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        
        let sizeInBytes = html.data(using: .utf8)?.count ?? 0
        let sizeInKB = Double(sizeInBytes) / 1024.0
        
        if sizeInKB > 500 {
            warnings.append(ValidationWarning(
                message: "Signature is very large (\(String(format: "%.1f", sizeInKB)) KB). Consider reducing content for better performance.",
                severity: .warning,
                category: .performance
            ))
        } else if sizeInKB > 100 {
            warnings.append(ValidationWarning(
                message: "Signature is moderately large (\(String(format: "%.1f", sizeInKB)) KB). Monitor loading performance.",
                severity: .info,
                category: .performance
            ))
        }
        
        return warnings
    }
    
    // MARK: - Style Checks
    
    private func checkStyleBestPractices(_ html: String) -> [ValidationWarning] {
        var warnings: [ValidationWarning] = []
        
        // Check for inline styles vs style tags
        let styleTagPattern = "<style[^>]*>"
        let inlineStylePattern = "style\\s*="
        
        let hasStyleTags = html.range(of: styleTagPattern, options: [.regularExpression, .caseInsensitive]) != nil
        let hasInlineStyles = html.range(of: inlineStylePattern, options: [.regularExpression, .caseInsensitive]) != nil
        
        if hasStyleTags && !hasInlineStyles {
            warnings.append(ValidationWarning(
                message: "Using <style> tags without inline styles. Consider using inline styles for better email client compatibility.",
                severity: .info,
                category: .style
            ))
        }
        
        // Check for table-based layout
        let tablePattern = "<table[^>]*>"
        if html.range(of: tablePattern, options: [.regularExpression, .caseInsensitive]) != nil {
            warnings.append(ValidationWarning(
                message: "Table-based layout detected. This is good for email compatibility.",
                severity: .info,
                category: .style
            ))
        }
        
        return warnings
    }
    
    // MARK: - Utility Methods
    
    func getWarningsByCategory(_ warnings: [ValidationWarning]) -> [ValidationWarning.Category: [ValidationWarning]] {
        return Dictionary(grouping: warnings) { $0.category }
    }
    
    func getWarningsBySeverity(_ warnings: [ValidationWarning]) -> [ValidationWarning.Severity: [ValidationWarning]] {
        return Dictionary(grouping: warnings) { $0.severity }
    }
    
    func hasErrors(_ warnings: [ValidationWarning]) -> Bool {
        return warnings.contains { $0.severity == .error }
    }
    
    func hasWarnings(_ warnings: [ValidationWarning]) -> Bool {
        return warnings.contains { $0.severity == .warning }
    }
}