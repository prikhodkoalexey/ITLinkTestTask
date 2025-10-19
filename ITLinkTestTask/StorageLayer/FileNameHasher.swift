import Foundation
import CryptoKit

protocol FileNameHashing {
    func makeFileName(for key: String, fileExtension: String?) -> String
}

struct SHA256FileNameHasher: FileNameHashing {
    func makeFileName(for key: String, fileExtension: String?) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        guard let fileExtension, !fileExtension.isEmpty else {
            return hex
        }
        let trimmed = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !trimmed.isEmpty else { return hex }
        return hex + "." + trimmed
    }
}
