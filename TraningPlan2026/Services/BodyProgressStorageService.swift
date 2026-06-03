import Foundation
import UIKit

final class BodyProgressStorageService {
    static let shared = BodyProgressStorageService()
    private init() {}
    
    private let defaults = UserDefaults.standard
    private let entriesKey = "body_progress_entries"
    
    func loadEntries() -> [BodyProgressEntry] {
        guard let data = defaults.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([BodyProgressEntry].self, from: data) else {
            return []
        }
        return decoded
    }
    
    func saveEntries(_ entries: [BodyProgressEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: entriesKey)
        }
    }
    
    func savePhoto(_ image: UIImage, entryId: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        let filename = "body_progress_\(entryId).jpg"
        let url = photoURL(filename: filename)
        
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }
    
    func savePhotoData(_ data: Data, entryId: String) -> String? {
        let filename = "body_progress_\(entryId).jpg"
        let url = photoURL(filename: filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            return nil
        }
    }
    
    func loadPhoto(filename: String) -> UIImage? {
        let url = photoURL(filename: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    func loadPhotoData(filename: String) -> Data? {
        try? Data(contentsOf: photoURL(filename: filename))
    }
    
    func deletePhoto(filename: String?) {
        guard let filename else { return }
        let url = photoURL(filename: filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func photoURL(filename: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(filename)
    }
}
