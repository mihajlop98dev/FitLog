import SwiftUI
import PhotosUI
import Charts

struct BodyProgressView: View {
    enum ProgressSection: String, CaseIterable {
        case measures = "Mere"
        case charts = "Grafikoni"
    }
    
    @ObservedObject var viewModel: BodyProgressViewModel
    @State private var showingAdd = false
    @AppStorage("progress.selectedSection") private var selectedSectionRaw: String = ProgressSection.measures.rawValue
    
    private var selectedSection: ProgressSection {
        get { ProgressSection(rawValue: selectedSectionRaw) ?? .measures }
        nonmutating set { selectedSectionRaw = newValue.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Napredak")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppDesign.textPrimary)
                        
                        Picker("Sekcija", selection: Binding(
                            get: { selectedSection },
                            set: { newValue in
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    selectedSection = newValue
                                }
                            }
                        )) {
                            ForEach(ProgressSection.allCases, id: \.self) { section in
                                Text(section.rawValue).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(AppDesign.accent)
                        
                        if selectedSection == .measures {
                            if viewModel.entries.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "camera.metering.matrix")
                                        .font(.system(size: 42))
                                        .foregroundStyle(AppDesign.textSecondary)
                                    Text("Nema unosa napretka")
                                        .font(.headline)
                                        .foregroundStyle(AppDesign.textPrimary)
                                    Text("Dodaj fotografiju i mere da pratiš promene.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppDesign.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .appCard()
                            } else {
                                ForEach(viewModel.entries) { entry in
                                    NavigationLink(destination: BodyProgressDetailView(entry: entry, viewModel: viewModel)) {
                                        BodyProgressRow(entry: entry, image: viewModel.image(for: entry))
                                    }
                                    .buttonStyle(PressableCardButtonStyle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            Task { await viewModel.deleteEntry(entry) }
                                        } label: {
                                            Label("Obriši unos", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } else {
                            if viewModel.entries.count >= 2 {
                                BodyProgressTrendsCard(entries: viewModel.entries)
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.system(size: 42))
                                        .foregroundStyle(AppDesign.textSecondary)
                                    Text("Nema dovoljno podataka za grafikone")
                                        .font(.headline)
                                        .foregroundStyle(AppDesign.textPrimary)
                                    Text("Dodaj bar 2 unosa da vidiš trend.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppDesign.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .appCard()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Napredak")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(AppDesign.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddBodyProgressEntryView(viewModel: viewModel)
            }
            .alert("Greška", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}

private struct BodyProgressTrendsCard: View {
    let entries: [BodyProgressEntry]
    
    private enum TrendFilter: String, CaseIterable {
        case all = "Sve"
        case weight = "Težina"
        case waist = "Struk"
        case chest = "Grudi"
        case arm = "Ruka"
    }
    
    @State private var selectedFilter: TrendFilter = .all
    
    private var sortedEntries: [BodyProgressEntry] {
        entries.sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend napretka")
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            Picker("Metrika", selection: $selectedFilter) {
                ForEach(TrendFilter.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            
            Chart {
                ForEach(sortedEntries) { entry in
                    if shouldShow(.weight), let weight = entry.weight {
                        LineMark(
                            x: .value("Datum", entry.date),
                            y: .value("Težina", weight)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                    }
                    if shouldShow(.waist), let waist = entry.waist {
                        LineMark(
                            x: .value("Datum", entry.date),
                            y: .value("Struk", waist)
                        )
                        .foregroundStyle(.green)
                        .interpolationMethod(.catmullRom)
                    }
                    if shouldShow(.chest), let chest = entry.chest {
                        LineMark(
                            x: .value("Datum", entry.date),
                            y: .value("Grudi", chest)
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)
                    }
                    if shouldShow(.arm), let arm = entry.arm {
                        LineMark(
                            x: .value("Datum", entry.date),
                            y: .value("Ruka", arm)
                        )
                        .foregroundStyle(.purple)
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .frame(height: 190)
            
            HStack(spacing: 12) {
                if shouldShow(.weight) { legend("Težina", color: .blue) }
                if shouldShow(.waist) { legend("Struk", color: .green) }
                if shouldShow(.chest) { legend("Grudi", color: .orange) }
                if shouldShow(.arm) { legend("Ruka", color: .purple) }
            }
            
            if let stats = selectedMetricStats {
                HStack(spacing: 12) {
                    statsPill("Min", value: stats.min, unit: stats.unit)
                    statsPill("Max", value: stats.max, unit: stats.unit)
                    statsPill("Avg", value: stats.avg, unit: stats.unit)
                }
            } else if selectedFilter == .all {
                Text("Za min/max/prosek izaberi jednu metriku.")
                    .font(.caption)
                    .foregroundStyle(AppDesign.textSecondary)
            }
        }
        .appCard()
    }
    
    private func shouldShow(_ filter: TrendFilter) -> Bool {
        selectedFilter == .all || selectedFilter == filter
    }
    
    private var selectedMetricStats: (min: Double, max: Double, avg: Double, unit: String)? {
        switch selectedFilter {
        case .all:
            return nil
        case .weight:
            return calculateStats(values: sortedEntries.compactMap(\.weight), unit: "kg")
        case .waist:
            return calculateStats(values: sortedEntries.compactMap(\.waist), unit: "cm")
        case .chest:
            return calculateStats(values: sortedEntries.compactMap(\.chest), unit: "cm")
        case .arm:
            return calculateStats(values: sortedEntries.compactMap(\.arm), unit: "cm")
        }
    }
    
    private func calculateStats(values: [Double], unit: String) -> (min: Double, max: Double, avg: Double, unit: String)? {
        guard let minValue = values.min(), let maxValue = values.max(), !values.isEmpty else {
            return nil
        }
        let avgValue = values.reduce(0, +) / Double(values.count)
        return (minValue, maxValue, avgValue, unit)
    }
    
    private func statsPill(_ title: String, value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppDesign.textSecondary)
            Text("\(String(format: "%.1f", value)) \(unit)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppDesign.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppDesign.cardSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private func legend(_ text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppDesign.textSecondary)
        }
    }
}

private struct BodyProgressRow: View {
    let entry: BodyProgressEntry
    let image: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Rectangle().fill(AppDesign.cardSecondary)
                        Image(systemName: "photo")
                            .foregroundStyle(AppDesign.textSecondary)
                    }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(formattedDate(entry.date))
                    .font(.headline)
                    .foregroundStyle(AppDesign.textPrimary)
                
                HStack(spacing: 8) {
                    if let weight = entry.weight {
                        metricPill("Težina \(String(format: "%.1f", weight))kg")
                    }
                    if let waist = entry.waist {
                        metricPill("Struk \(Int(waist))cm")
                    }
                }
                
                if entry.analysis != nil {
                    Text("AI analiza dostupna")
                        .font(.caption)
                        .foregroundStyle(AppDesign.accent)
                }
                
                if let comparison = entry.comparison {
                    comparisonBadge(comparison)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppDesign.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppDesign.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func metricPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppDesign.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppDesign.cardSecondary)
            .clipShape(Capsule())
    }
    
    private func comparisonBadge(_ comparison: BodyProgressComparisonAnalysis) -> some View {
        let hasVisibleProgress = !comparison.visibleProgressAreas.isEmpty
        let title = hasVisibleProgress ? "Napredak" : "Bez jasne promene"
        let tint = hasVisibleProgress ? AppDesign.accent : AppDesign.textSecondary
        
        return Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.85))
            .clipShape(Capsule())
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sr_RS")
        formatter.dateFormat = "d. MMM yyyy"
        return formatter.string(from: date)
    }
}

private struct AddBodyProgressEntryView: View {
    @ObservedObject var viewModel: BodyProgressViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var date = Date()
    @State private var weight = ""
    @State private var waist = ""
    @State private var chest = ""
    @State private var arm = ""
    @State private var shouldAnalyze = true
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        DatePicker("Datum", selection: $date, displayedComponents: .date)
                            .tint(AppDesign.accent)
                            .foregroundStyle(AppDesign.textPrimary)
                            .appCard()
                        
                        metricField("Težina (kg)", text: $weight)
                        metricField("Obim struka (cm)", text: $waist)
                        metricField("Obim grudi (cm)", text: $chest)
                        metricField("Obim ruke (cm)", text: $arm)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Fotografija")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 180)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AppDesign.cardSecondary)
                                        .frame(height: 140)
                                        .overlay {
                                            VStack(spacing: 6) {
                                                Image(systemName: "photo.badge.plus")
                                                Text("Dodaj progress fotografiju")
                                                    .font(.subheadline)
                                            }
                                            .foregroundStyle(AppDesign.textSecondary)
                                        }
                                }
                            }
                            
                            Toggle("AI analiza fotografije", isOn: $shouldAnalyze)
                                .tint(AppDesign.accent)
                                .foregroundStyle(AppDesign.textPrimary)
                        }
                        .appCard()
                        
                        Button {
                            Task {
                                await viewModel.addEntry(
                                    date: date,
                                    weight: Double(weight.replacingOccurrences(of: ",", with: ".")),
                                    waist: Double(waist.replacingOccurrences(of: ",", with: ".")),
                                    chest: Double(chest.replacingOccurrences(of: ",", with: ".")),
                                    arm: Double(arm.replacingOccurrences(of: ",", with: ".")),
                                    photo: selectedImage,
                                    analyzeWithAI: shouldAnalyze
                                )
                                dismiss()
                            }
                        } label: {
                            HStack {
                                if viewModel.isLoading || viewModel.isAnalyzing {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(viewModel.isAnalyzing ? "AI analiza..." : "Sačuvaj unos")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppDesign.accent)
                        .disabled(viewModel.isLoading || viewModel.isAnalyzing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Novi unos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Otkaži") { dismiss() }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func metricField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
            TextField(title, text: text)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppDesign.cardSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(AppDesign.textPrimary)
        }
        .appCard()
    }
}

private struct BodyProgressDetailView: View {
    let entry: BodyProgressEntry
    @ObservedObject var viewModel: BodyProgressViewModel
    
    var body: some View {
        let currentEntry = viewModel.entry(withId: entry.id) ?? entry
        
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if let image = viewModel.image(for: currentEntry) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .appCard()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mere")
                        .font(.headline)
                        .foregroundStyle(AppDesign.textPrimary)
                    measureRow("Datum", value: formattedDate(currentEntry.date))
                    measureRow("Težina", value: currentEntry.weight.map { String(format: "%.1f kg", $0) } ?? "-")
                    measureRow("Struk", value: currentEntry.waist.map { String(format: "%.1f cm", $0) } ?? "-")
                    measureRow("Grudi", value: currentEntry.chest.map { String(format: "%.1f cm", $0) } ?? "-")
                    measureRow("Ruka", value: currentEntry.arm.map { String(format: "%.1f cm", $0) } ?? "-")
                }
                .appCard()
                
                if let analysis = currentEntry.analysis {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI procena")
                            .font(.headline)
                            .foregroundStyle(AppDesign.textPrimary)
                        Text(analysis.summary)
                            .foregroundStyle(AppDesign.textPrimary)
                        Text("Trend masti: \(analysis.bodyFatTrend)")
                            .font(.subheadline)
                            .foregroundStyle(AppDesign.textSecondary)
                        Text("Postura: \(analysis.posture)")
                            .font(.subheadline)
                            .foregroundStyle(AppDesign.textSecondary)
                        ForEach(analysis.recommendations, id: \.self) { rec in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").foregroundStyle(AppDesign.accent)
                                Text(rec).foregroundStyle(AppDesign.textSecondary)
                            }
                        }
                        Text(analysis.disclaimer)
                            .font(.caption)
                            .foregroundStyle(AppDesign.textSecondary)
                    }
                    .appCard()
                } else if currentEntry.photoFilename != nil {
                    Button {
                        Task { await viewModel.analyzeEntry(currentEntry) }
                    } label: {
                        Label("Pokreni AI analizu", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppDesign.accent)
                }
                
                if let comparison = currentEntry.comparison,
                   let currentImage = viewModel.image(for: currentEntry),
                   let previous = viewModel.previousEntry(for: currentEntry),
                   let previousImage = viewModel.image(for: previous) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Poređenje sa prethodnim unosom")
                            .font(.headline)
                            .foregroundStyle(AppDesign.textPrimary)
                        
                        HStack(spacing: 10) {
                            comparedImageCard(title: "Pre", image: previousImage)
                            comparedImageCard(title: "Posle", image: currentImage)
                        }
                        
                        Text(comparison.summary)
                            .foregroundStyle(AppDesign.textPrimary)
                        
                        if let measurementsSummary = comparison.measurementsSummary,
                           !measurementsSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Mere (težina/obimi):")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppDesign.textPrimary)
                            Text(measurementsSummary)
                                .foregroundStyle(AppDesign.textSecondary)
                        }
                        
                        if !comparison.visibleProgressAreas.isEmpty {
                            Text("Napredak se vidi:")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppDesign.textPrimary)
                            ForEach(comparison.visibleProgressAreas, id: \.self) { area in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•").foregroundStyle(AppDesign.accent)
                                    Text(area).foregroundStyle(AppDesign.textSecondary)
                                }
                            }
                        }
                        
                        if !comparison.noClearChangeAreas.isEmpty {
                            Text("Bez jasne promene:")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppDesign.textPrimary)
                            ForEach(comparison.noClearChangeAreas, id: \.self) { area in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•").foregroundStyle(AppDesign.accent)
                                    Text(area).foregroundStyle(AppDesign.textSecondary)
                                }
                            }
                        }
                        
                        Text("Pouzdanost: \(Int(comparison.confidence * 100))%")
                            .font(.caption)
                            .foregroundStyle(AppDesign.textSecondary)
                        Text(comparison.disclaimer)
                            .font(.caption)
                            .foregroundStyle(AppDesign.textSecondary)
                    }
                    .appCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .background(AppDesign.background.ignoresSafeArea())
        .navigationTitle("Detalji napretka")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func comparedImageCard(title: String, image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppDesign.textSecondary)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func measureRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppDesign.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(AppDesign.textPrimary)
        }
        .font(.subheadline)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sr_RS")
        formatter.dateFormat = "d. MMMM yyyy"
        return formatter.string(from: date)
    }
}
