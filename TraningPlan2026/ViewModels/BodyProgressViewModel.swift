import Foundation
import Combine
import UIKit

@MainActor
final class BodyProgressViewModel: ObservableObject {
    @Published var entries: [BodyProgressEntry] = []
    @Published var isLoading = false
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    
    private let storage = BodyProgressStorageService.shared
    private let supabase = SupabaseService()
    
    init() {
        Task { await loadEntries() }
    }
    
    func loadEntries() async {
        let localEntries = storage.loadEntries().sorted { $0.date > $1.date }
        if !localEntries.isEmpty {
            entries = localEntries
        }
        
        do {
            let remote = try await supabase.fetchBodyProgressEntries()
            var mapped: [BodyProgressEntry] = []
            for item in remote {
                if let mappedItem = await mapRemoteToEntry(item) {
                    mapped.append(mappedItem)
                }
            }
            mapped.sort { $0.date > $1.date }
            entries = mapped
            storage.saveEntries(mapped)
        } catch {
            if entries.isEmpty {
                entries = localEntries
            }
        }
    }
    
    func image(for entry: BodyProgressEntry) -> UIImage? {
        guard let filename = entry.photoFilename else { return nil }
        return storage.loadPhoto(filename: filename)
    }
    
    func addEntry(
        date: Date,
        weight: Double?,
        waist: Double?,
        chest: Double?,
        arm: Double?,
        photo: UIImage?,
        analyzeWithAI: Bool
    ) async {
        isLoading = true
        errorMessage = nil
        let previousEntryWithPhoto = entries.first(where: { $0.photoFilename != nil })
        
        var entry = BodyProgressEntry(
            date: date,
            weight: weight,
            waist: waist,
            chest: chest,
            arm: arm,
            photoFilename: nil,
            analysis: nil,
            comparison: nil
        )
        
        if let photo {
            entry.photoFilename = storage.savePhoto(photo, entryId: entry.id)
        }
        
        if analyzeWithAI,
           let filename = entry.photoFilename,
           let photoData = storage.loadPhotoData(filename: filename) {
            isAnalyzing = true
            let analysis = await ProgressAIService.analyzeProgressPhoto(
                imageData: photoData,
                weight: weight,
                waist: waist,
                chest: chest,
                arm: arm
            )
            entry.analysis = analysis
            
            if let previous = previousEntryWithPhoto,
               let previousFilename = previous.photoFilename,
               let previousPhotoData = storage.loadPhotoData(filename: previousFilename) {
                let comparison = await ProgressAIService.compareProgressPhotos(
                    previousImageData: previousPhotoData,
                    currentImageData: photoData,
                    previousDate: previous.date,
                    currentDate: entry.date,
                    previousWeight: previous.weight,
                    currentWeight: entry.weight,
                    previousWaist: previous.waist,
                    currentWaist: entry.waist,
                    previousChest: previous.chest,
                    currentChest: entry.chest,
                    previousArm: previous.arm,
                    currentArm: entry.arm
                )
                entry.comparison = comparison
            }
            isAnalyzing = false
        }
        
        entries.insert(entry, at: 0)
        storage.saveEntries(entries)
        
        if let localPhotoFilename = entry.photoFilename,
           let localPhotoData = storage.loadPhotoData(filename: localPhotoFilename) {
            do {
                let remotePath = try await supabase.uploadBodyProgressPhoto(data: localPhotoData, entryId: entry.id)
                if let index = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries[index].photoRemotePath = remotePath
                    storage.saveEntries(entries)
                    entry.photoRemotePath = remotePath
                }
            } catch {
                errorMessage = "Upload slike na cloud nije uspeo: \(error.localizedDescription)"
            }
        }
        
        await syncEntryToRemote(entry)
        isLoading = false
    }
    
    func analyzeEntry(_ entry: BodyProgressEntry) async {
        guard let filename = entry.photoFilename,
              let photoData = storage.loadPhotoData(filename: filename),
              let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            return
        }
        
        isAnalyzing = true
        let analysis = await ProgressAIService.analyzeProgressPhoto(
            imageData: photoData,
            weight: entry.weight,
            waist: entry.waist,
            chest: entry.chest,
            arm: entry.arm
        )
        isAnalyzing = false
        
        guard let analysis else {
            errorMessage = "AI analiza nije uspela. Proveri internet ili API ključ."
            return
        }
        
        entries[index].analysis = analysis
        
        if let previous = previousEntry(for: entry),
           let previousFilename = previous.photoFilename,
           let previousPhotoData = storage.loadPhotoData(filename: previousFilename) {
            let comparison = await ProgressAIService.compareProgressPhotos(
                previousImageData: previousPhotoData,
                currentImageData: photoData,
                previousDate: previous.date,
                currentDate: entry.date,
                previousWeight: previous.weight,
                currentWeight: entry.weight,
                previousWaist: previous.waist,
                currentWaist: entry.waist,
                previousChest: previous.chest,
                currentChest: entry.chest,
                previousArm: previous.arm,
                currentArm: entry.arm
            )
            entries[index].comparison = comparison
        }
        
        storage.saveEntries(entries)
        
        await syncEntryToRemote(entries[index])
    }
    
    func deleteEntry(_ entry: BodyProgressEntry) async {
        storage.deletePhoto(filename: entry.photoFilename)
        entries.removeAll { $0.id == entry.id }
        storage.saveEntries(entries)
        
        if let remotePath = entry.photoRemotePath {
            await supabase.deleteBodyProgressPhoto(path: remotePath)
        }
        
        do {
            try await supabase.deleteBodyProgressEntry(id: entry.id)
        } catch {
            errorMessage = "Brisanje sa clouda nije uspelo: \(error.localizedDescription)"
        }
    }
    
    private func syncEntryToRemote(_ entry: BodyProgressEntry) async {
        do {
            var remotePath = entry.photoRemotePath
            if remotePath == nil,
               let filename = entry.photoFilename,
               let localData = storage.loadPhotoData(filename: filename) {
                if let uploadedPath = try? await supabase.uploadBodyProgressPhoto(data: localData, entryId: entry.id) {
                    remotePath = uploadedPath
                    if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                        entries[idx].photoRemotePath = uploadedPath
                        storage.saveEntries(entries)
                    }
                }
            }
            
            let analysisJSON = try entry.analysis.flatMap { analysis in
                let data = try JSONEncoder().encode(analysis)
                return String(data: data, encoding: .utf8)
            }
            let photoBase64: String?
            if remotePath != nil {
                photoBase64 = nil
            } else if let filename = entry.photoFilename,
               let data = storage.loadPhotoData(filename: filename) {
                photoBase64 = data.base64EncodedString()
            } else {
                photoBase64 = nil
            }
            
            let payload = BodyProgressUpsertData(
                id: entry.id,
                date: entry.date,
                weight: entry.weight,
                waist: entry.waist,
                chest: entry.chest,
                arm: entry.arm,
                photo_path: remotePath,
                photo_base64: photoBase64,
                analysis_json: analysisJSON,
                comparison_json: comparisonJSON(for: entry.comparison)
            )
            try await supabase.saveBodyProgressEntry(payload)
        } catch {
            errorMessage = "Cloud sync nije uspeo: \(error.localizedDescription)"
        }
    }
    
    private func mapRemoteToEntry(_ item: BodyProgressData) async -> BodyProgressEntry? {
        let photoFilename: String?
        if let remotePath = item.photo_path {
            if let data = try? await supabase.downloadBodyProgressPhoto(path: remotePath) {
                photoFilename = storage.savePhotoData(data, entryId: item.id)
            } else if let base64 = item.photo_base64,
                      let data = Data(base64Encoded: base64) {
                photoFilename = storage.savePhotoData(data, entryId: item.id)
            } else {
                photoFilename = nil
            }
        } else if let base64 = item.photo_base64,
           let data = Data(base64Encoded: base64) {
            photoFilename = storage.savePhotoData(data, entryId: item.id)
        } else {
            photoFilename = nil
        }
        
        let analysis: BodyProgressAnalysis?
        if let json = item.analysis_json,
           let data = json.data(using: .utf8) {
            analysis = try? JSONDecoder().decode(BodyProgressAnalysis.self, from: data)
        } else {
            analysis = nil
        }
        
        let comparison: BodyProgressComparisonAnalysis?
        if let json = item.comparison_json,
           let data = json.data(using: .utf8) {
            comparison = try? JSONDecoder().decode(BodyProgressComparisonAnalysis.self, from: data)
        } else {
            comparison = nil
        }
        
        return BodyProgressEntry(
            id: item.id,
            date: item.date,
            weight: item.weight,
            waist: item.waist,
            chest: item.chest,
            arm: item.arm,
            photoFilename: photoFilename,
            photoRemotePath: item.photo_path,
            analysis: analysis,
            comparison: comparison
        )
    }
    
    func previousEntry(for entry: BodyProgressEntry) -> BodyProgressEntry? {
        let sorted = entries.sorted { $0.date < $1.date }
        guard let currentIndex = sorted.firstIndex(where: { $0.id == entry.id }) else { return nil }
        guard currentIndex > 0 else { return nil }
        return sorted[currentIndex - 1]
    }
    
    func entry(withId id: String) -> BodyProgressEntry? {
        entries.first(where: { $0.id == id })
    }
    
    private func comparisonJSON(for comparison: BodyProgressComparisonAnalysis?) -> String? {
        guard let comparison else { return nil }
        guard let data = try? JSONEncoder().encode(comparison) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
