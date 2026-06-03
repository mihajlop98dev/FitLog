//
//  AddMealView.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import SwiftUI
import PhotosUI
import UIKit
import Vision

struct AddMealView: View {
    @ObservedObject var viewModel: MealViewModel
    @Environment(\.dismiss) var dismiss
    var initialDate: Date? = nil
    
    @State private var name = ""
    @State private var time = "Breakfast"
    @State private var calories = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var foods: [Meal.FoodItem] = []
    @State private var showingAddFood = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let mealTimes = ["Breakfast", "Lunch", "Dinner", "Snack", "Doručak", "Ručak", "Večera", "Užina"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Novi Obrok")
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppDesign.textPrimary)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Osnovne Informacije")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            
                            MealInputField(title: "Naziv obroka", text: $name)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Vreme")
                                    .font(.caption)
                                    .foregroundStyle(AppDesign.textSecondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(mealTimes, id: \.self) { mealTime in
                                            Button {
                                                Haptics.light()
                                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                                    time = mealTime
                                                }
                                            } label: {
                                                Text(mealTime)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(time == mealTime ? Color.black : AppDesign.textPrimary)
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 7)
                                                    .background(
                                                        Capsule(style: .continuous)
                                                            .fill(
                                                                time == mealTime
                                                                ? AnyShapeStyle(
                                                                    LinearGradient(
                                                                        colors: [AppDesign.accent, AppDesign.accent2],
                                                                        startPoint: .leading,
                                                                        endPoint: .trailing
                                                                    )
                                                                )
                                                                : AnyShapeStyle(AppDesign.cardSecondary)
                                                            )
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Datum")
                                    .font(.caption)
                                    .foregroundStyle(AppDesign.textSecondary)
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .tint(AppDesign.accent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppDesign.cardSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            
                            MealInputField(title: "Kalorije (ručno, opcionalno)", text: $calories, keyboard: .numberPad)
                        }
                        .appCard()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Namirnice")
                                    .font(.headline)
                                    .foregroundStyle(AppDesign.textPrimary)
                                Spacer()
                                Button {
                                    Haptics.light()
                                    showingAddFood = true
                                } label: {
                                    Label("Dodaj", systemImage: "plus.circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppDesign.accent)
                                }
                            }
                            
                            if foods.isEmpty {
                                Text("Nema dodatih namirnica.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppDesign.textSecondary)
                            } else {
                                ForEach(foods) { food in
                                    HStack(alignment: .top, spacing: 8) {
                                        FoodRowView(food: food)
                                        Spacer()
                                        Button {
                                            Haptics.light()
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                foods.removeAll { $0.id == food.id }
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red.opacity(0.85))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                        .appCard()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Napomene")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            TextEditor(text: $notes)
                                .frame(minHeight: 120)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(AppDesign.cardSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundStyle(AppDesign.textPrimary)
                        }
                        .appCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Novi Obrok")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Otkaži") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Sačuvaj") {
                            Haptics.medium()
                            saveMeal()
                        }
                        .disabled(name.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodItemView { food in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        foods.append(food)
                    }
                }
            }
            .alert("Greška", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage)
            }
            .animation(.easeInOut(duration: 0.2), value: foods.count)
        }
        .onAppear {
            if let initialDate {
                date = initialDate
            }
        }
    }
    
    private func saveMeal() {
        guard !name.isEmpty else {
            errorMessage = "Naziv obroka ne može biti prazan."
            showError = true
            return
        }
        
        let totalCalories = foods.compactMap(\.calories).reduce(0, +)
        let totalProtein = foods.compactMap(\.protein).reduce(0, +)
        let totalCarbs = foods.compactMap(\.carbs).reduce(0, +)
        let totalFat = foods.compactMap(\.fat).reduce(0, +)
        
        isSaving = true
        let meal = Meal(
            name: name,
            time: time,
            foods: foods,
            calories: Int(calories) ?? (totalCalories > 0 ? totalCalories : nil),
            protein: totalProtein > 0 ? totalProtein : nil,
            carbs: totalCarbs > 0 ? totalCarbs : nil,
            fat: totalFat > 0 ? totalFat : nil,
            date: date,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            await viewModel.addMeal(meal)
            await MainActor.run {
                isSaving = false
                if let error = viewModel.errorMessage {
                    Haptics.error()
                    errorMessage = error
                    showError = true
                } else {
                    Haptics.success()
                    dismiss()
                }
            }
        }
    }
}

struct FoodRowView: View {
    let food: Meal.FoodItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(food.name)
                .font(.headline)
                .foregroundStyle(AppDesign.textPrimary)
            
            HStack {
                if let quantity = food.quantity {
                    Text(quantity)
                        .font(.subheadline)
                        .foregroundStyle(AppDesign.textSecondary)
                }
                
                if let calories = food.calories {
                    Text("\(calories) kcal")
                        .font(.subheadline)
                        .foregroundStyle(AppDesign.textSecondary)
                }
            }
        }
    }
}

struct AddFoodItemView: View {
    enum QuantityUnit: String, CaseIterable {
        case g = "g"
        case kg = "kg"
        case ml = "ml"
        case piece = "kom"
    }
    
    @Environment(\.dismiss) var dismiss
    let onSave: (Meal.FoodItem) -> Void
    
    @State private var name = ""
    @State private var quantityAmount = "100"
    @State private var quantityUnit: QuantityUnit = .g
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var isEstimating = false
    @State private var isScanningLabel = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var labelImage: UIImage?
    @State private var showingCamera = false
    @State private var showingCropper = false
    @State private var scanInfoMessage = ""
    @State private var scannedPer100: NutritionEstimate?
    @State private var ocrDebugText = ""
    @State private var showOCRDebug = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppDesign.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Osnovne Informacije")
                                .font(.headline)
                                .foregroundStyle(AppDesign.textPrimary)
                            MealInputField(title: "Naziv namirnice", text: $name)
                            quantityInput
                            MealInputField(title: "Kalorije", text: $calories, keyboard: .numberPad)
                            MealInputField(title: "Protein (g)", text: $protein, keyboard: .decimalPad)
                            MealInputField(title: "Ugljeni hidrati (g)", text: $carbs, keyboard: .decimalPad)
                            MealInputField(title: "Masti (g)", text: $fat, keyboard: .decimalPad)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Skeniranje deklaracije")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppDesign.textPrimary)
                                
                                HStack(spacing: 10) {
                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                        Label("Izaberi sliku", systemImage: "photo.on.rectangle")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppDesign.accent)
                                    }
                                    .disabled(isScanningLabel)
                                    
                                    Button {
                                        showingCamera = true
                                    } label: {
                                        Label("Slikaj", systemImage: "camera.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppDesign.accent)
                                    }
                                    .disabled(isScanningLabel)
                                    
                                    if isScanningLabel {
                                        ProgressView()
                                            .tint(AppDesign.accent)
                                    }
                                }
                                
                                if let labelImage {
                                    Image(uiImage: labelImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 130)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    Text("Zona deklaracije se otvara automatski odmah nakon slikanja/izbora slike.")
                                        .font(.caption2)
                                        .foregroundStyle(AppDesign.textSecondary)
                                }
                                
                                if !scanInfoMessage.isEmpty {
                                    Text(scanInfoMessage)
                                        .font(.caption)
                                        .foregroundStyle(AppDesign.textSecondary)
                                }
                                
                                if !ocrDebugText.isEmpty {
                                    DisclosureGroup(isExpanded: $showOCRDebug) {
                                        ScrollView {
                                            Text(ocrDebugText)
                                                .font(.caption2.monospaced())
                                                .foregroundStyle(AppDesign.textSecondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(8)
                                        }
                                        .frame(maxHeight: 180)
                                        .background(AppDesign.cardSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    } label: {
                                        Label("OCR tekst (debug)", systemImage: "text.viewfinder")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppDesign.accent)
                                    }
                                }
                            }
                            
                            Button {
                                Task {
                                    await applyEstimatedNutrition()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if isEstimating {
                                        ProgressView()
                                            .tint(AppDesign.accent)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(isEstimating ? "Računam..." : "AI procena nutritivnih vrednosti")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppDesign.accent)
                            }
                            .disabled(isEstimating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .appCard()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Nova Namirnica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Otkaži") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Dodaj") {
                        Haptics.medium()
                        saveFood()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraImagePicker { image in
                    labelImage = image
                    showingCropper = true
                }
            }
            .sheet(isPresented: $showingCropper) {
                if let image = labelImage {
                    NutritionImageCropperView(image: image) { cropped in
                        labelImage = cropped
                        Task { await applyNutritionFromLabelImage(cropped) }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        labelImage = image
                        showingCropper = true
                    }
                }
            }
            .onChange(of: quantityAmount) { _, _ in
                applyScannedScaleIfAvailable()
            }
            .onChange(of: quantityUnit) { _, _ in
                applyScannedScaleIfAvailable()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveFood() {
        let food = Meal.FoodItem(
            name: name,
            quantity: normalizedQuantityString.isEmpty ? nil : normalizedQuantityString,
            calories: Int(calories),
            protein: Double(protein),
            carbs: Double(carbs),
            fat: Double(fat)
        )
        Haptics.success()
        onSave(food)
        dismiss()
    }
    
    private func applyEstimatedNutrition() async {
        isEstimating = true
        defer { isEstimating = false }
        
        if let aiEstimate = await NutritionAIService.estimate(foodName: name, quantity: quantity) {
            Haptics.success()
            calories = "\(aiEstimate.calories)"
            protein = String(format: "%.1f", aiEstimate.protein)
            carbs = String(format: "%.1f", aiEstimate.carbs)
            fat = String(format: "%.1f", aiEstimate.fat)
            return
        }
        
        guard let estimate = NutritionEstimatorService.estimate(foodName: name, quantity: quantity) else {
            Haptics.error()
            return
        }
        
        // Fallback to local estimator if AI key/network is unavailable.
        Haptics.light()
        calories = "\(estimate.calories)"
        protein = String(format: "%.1f", estimate.protein)
        carbs = String(format: "%.1f", estimate.carbs)
        fat = String(format: "%.1f", estimate.fat)
    }
    
    private func applyNutritionFromLabelImage(_ image: UIImage) async {
        isScanningLabel = true
        scanInfoMessage = ""
        defer { isScanningLabel = false }
        
        guard let scan = await NutritionLabelScannerService.scanNutrition(from: image) else {
            Haptics.error()
            return
        }
        
        Haptics.success()

        let basis = max(scan.basisGrams ?? 100, 1)
        let scaleTo100 = 100.0 / basis
        scannedPer100 = NutritionEstimate(
            calories: Int((Double(scan.estimate.calories) * scaleTo100).rounded()),
            protein: scan.estimate.protein * scaleTo100,
            carbs: scan.estimate.carbs * scaleTo100,
            fat: scan.estimate.fat * scaleTo100
        )
        ocrDebugText = scan.rawOCRText
        
        // Nakon skena postavi podrazumevano 100g i automatski popuni sva polja.
        quantityAmount = "100"
        quantityUnit = .g
        applyScannedScaleIfAvailable()
        scanInfoMessage = "Deklaracija je postavljena na 100g. Menjaj gramažu i vrednosti će se automatski preračunati."
    }
    
    private func grams(from quantityText: String) -> Double? {
        let lower = quantityText.lowercased().replacingOccurrences(of: ",", with: ".")
        guard let value = lower.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .first(where: { !$0.isEmpty })
            .flatMap(Double.init) else {
            return nil
        }
        
        if lower.contains("kg") { return value * 1000 }
        if lower.contains("g") || lower.contains("gr") { return value }
        if lower.contains("ml") { return value } // aproksimacija 1ml ~= 1g za većinu tečnosti
        return nil
    }
    
    private func adjustedEstimate(
        _ estimate: NutritionEstimate,
        quantityGrams: Double?,
        basisGrams: Double?
    ) -> NutritionEstimate {
        guard let quantityGrams,
              let basisGrams,
              basisGrams > 0 else {
            return estimate
        }
        
        let factor = quantityGrams / basisGrams
        return NutritionEstimate(
            calories: Int((Double(estimate.calories) * factor).rounded()),
            protein: estimate.protein * factor,
            carbs: estimate.carbs * factor,
            fat: estimate.fat * factor
        )
    }
    
    private func applyScannedScaleIfAvailable() {
        guard let per100 = scannedPer100 else { return }
        let gramsValue = max(currentQuantityInGrams(), 1)
        let factor = gramsValue / 100.0
        
        let scaled = NutritionEstimate(
            calories: Int((Double(per100.calories) * factor).rounded()),
            protein: per100.protein * factor,
            carbs: per100.carbs * factor,
            fat: per100.fat * factor
        )
        
        calories = "\(scaled.calories)"
        protein = String(format: "%.1f", scaled.protein)
        carbs = String(format: "%.1f", scaled.carbs)
        fat = String(format: "%.1f", scaled.fat)
    }
    
    private var quantity: String {
        normalizedQuantityString
    }
    
    private var normalizedQuantityString: String {
        let raw = quantityAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "" }
        
        if quantityUnit == .piece {
            return "\(raw) \(quantityUnit.rawValue)"
        }
        return "\(raw)\(quantityUnit.rawValue)"
    }
    
    private func currentQuantityInGrams() -> Double {
        let normalized = quantityAmount
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return 100 }
        
        switch quantityUnit {
        case .g:
            return value
        case .kg:
            return value * 1000
        case .ml:
            return value
        case .piece:
            // Use food-specific average piece weight when available (e.g. egg, apple).
            return value * NutritionEstimatorService.estimatedPieceGrams(for: name)
        }
    }
    
    private var quantityInput: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Količina")
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
            HStack(spacing: 8) {
                TextField("100", text: $quantityAmount)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppDesign.cardSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(AppDesign.textPrimary)
                
                Picker("Jedinica", selection: $quantityUnit) {
                    ForEach(QuantityUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }
        }
    }
}

private struct MealInputField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppDesign.textSecondary)
            TextField(title, text: $text)
                .keyboardType(keyboard)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppDesign.cardSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .foregroundStyle(AppDesign.textPrimary)
        }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }
    
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction
        
        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }
    }
}

private struct NutritionImageCropperView: View {
    let image: UIImage
    let onConfirm: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var cropRect: CGRect = .zero
    @State private var imageFrame: CGRect = .zero
    @State private var isAutoDetecting = false
    @State private var autoDetectMessage = ""
    
    private let minCropSize: CGFloat = 80
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    AppDesign.background.ignoresSafeArea()
                    
                    let frame = fittedFrame(container: geo.size, imageSize: image.size)
                    Color.clear
                        .onAppear {
                            initializeCropIfNeeded(frame: frame)
                        }
                        .onChange(of: geo.size) { _, _ in
                            initializeCropIfNeeded(frame: frame)
                        }
                    
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    
                    VStack {
                        Text("Prevuci okvir za pomeranje, a ručke po uglovima za promenu veličine.")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppDesign.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppDesign.cardSecondary.opacity(0.9))
                            .clipShape(Capsule())
                            .padding(.top, 8)
                        Spacer()
                    }
                    
                    if cropRect != .zero {
                        cropOverlay
                    }
                }
            }
            .navigationTitle("Označi zonu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Otkaži") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await autoDetectNutritionZone() }
                    } label: {
                        if isAutoDetecting {
                            ProgressView()
                                .tint(AppDesign.accent)
                        } else {
                            Text("Auto")
                        }
                    }
                    .disabled(isAutoDetecting || imageFrame == .zero)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Primeni") {
                        if let cropped = cropImage(image: image, imageFrame: imageFrame, cropRect: cropRect) {
                            onConfirm(cropped)
                        }
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .bottom) {
            if !autoDetectMessage.isEmpty {
                Text(autoDetectMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppDesign.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppDesign.cardSecondary)
                    .clipShape(Capsule())
                    .padding(.bottom, 14)
                    .transition(.opacity)
            }
        }
    }
    
    private var cropOverlay: some View {
        ZStack {
            // Dim everything outside the crop area so users clearly see what is selected.
            Color.black.opacity(0.38)
                .mask(
                    Rectangle()
                        .overlay(
                            Rectangle()
                                .frame(width: cropRect.width, height: cropRect.height)
                                .position(x: cropRect.midX, y: cropRect.midY)
                                .blendMode(.destinationOut)
                        )
                        .compositingGroup()
                )
                .allowsHitTesting(false)
            
            Rectangle()
                .stroke(AppDesign.accent, lineWidth: 2.5)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
            
            // Drag anywhere inside selected area to move it.
            Rectangle()
                .fill(Color.clear)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let halfW = cropRect.width / 2
                            let halfH = cropRect.height / 2
                            var center = value.location
                            center.x = min(max(center.x, imageFrame.minX + halfW), imageFrame.maxX - halfW)
                            center.y = min(max(center.y, imageFrame.minY + halfH), imageFrame.maxY - halfH)
                            cropRect.origin = CGPoint(x: center.x - halfW, y: center.y - halfH)
                        }
                )
            
            // Bottom-right resize handle.
            Circle()
                .fill(AppDesign.accent)
                .frame(width: 22, height: 22)
                .position(x: cropRect.minX, y: cropRect.minY)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            resizeFromTopLeft(to: value.location)
                        }
                )
            
            Circle()
                .fill(AppDesign.accent)
                .frame(width: 22, height: 22)
                .position(x: cropRect.maxX, y: cropRect.minY)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            resizeFromTopRight(to: value.location)
                        }
                )
            
            Circle()
                .fill(AppDesign.accent)
                .frame(width: 22, height: 22)
                .position(x: cropRect.minX, y: cropRect.maxY)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            resizeFromBottomLeft(to: value.location)
                        }
                )
            
            Circle()
                .fill(AppDesign.accent)
                .frame(width: 22, height: 22)
                .position(x: cropRect.maxX, y: cropRect.maxY)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            resizeFromBottomRight(to: value.location)
                        }
                )
        }
    }
    
    private func fittedFrame(container: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let w = imageSize.width * scale
        let h = imageSize.height * scale
        let x = (container.width - w) / 2
        let y = (container.height - h) / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    private func cropImage(image: UIImage, imageFrame: CGRect, cropRect: CGRect) -> UIImage? {
        let fixed = image.fixedOrientation()
        guard let cgImage = fixed.cgImage, imageFrame.width > 0, imageFrame.height > 0 else { return nil }
        
        let normalized = CGRect(
            x: (cropRect.minX - imageFrame.minX) / imageFrame.width,
            y: (cropRect.minY - imageFrame.minY) / imageFrame.height,
            width: cropRect.width / imageFrame.width,
            height: cropRect.height / imageFrame.height
        )
        
        let pixelRect = CGRect(
            x: max(0, normalized.minX * CGFloat(cgImage.width)),
            y: max(0, normalized.minY * CGFloat(cgImage.height)),
            width: min(CGFloat(cgImage.width), normalized.width * CGFloat(cgImage.width)),
            height: min(CGFloat(cgImage.height), normalized.height * CGFloat(cgImage.height))
        ).integral
        
        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return UIImage(cgImage: cropped)
    }
    
    private func autoDetectNutritionZone() async {
        isAutoDetecting = true
        defer { isAutoDetecting = false }
        
        guard let normalizedRect = await detectNutritionRegion(in: image.fixedOrientation()) else {
            withAnimation(.easeInOut(duration: 0.2)) {
                autoDetectMessage = "Auto detekcija nije uspela, označi zonu ručno."
            }
            return
        }
        
        let detected = CGRect(
            x: imageFrame.minX + normalizedRect.minX * imageFrame.width,
            y: imageFrame.minY + (1 - normalizedRect.maxY) * imageFrame.height,
            width: normalizedRect.width * imageFrame.width,
            height: normalizedRect.height * imageFrame.height
        )
        
        let minSize: CGFloat = 60
        let safeRect = CGRect(
            x: max(imageFrame.minX, detected.minX),
            y: max(imageFrame.minY, detected.minY),
            width: max(minSize, min(detected.width, imageFrame.maxX - max(imageFrame.minX, detected.minX))),
            height: max(minSize, min(detected.height, imageFrame.maxY - max(imageFrame.minY, detected.minY)))
        )
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            cropRect = safeRect
            autoDetectMessage = "Auto detekcija završena. Po potrebi ručno koriguj okvir."
        }
    }
    
    private func detectNutritionRegion(in image: UIImage) async -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let keywords = [
                    "kcal", "energ", "energy",
                    "protein", "proteini",
                    "ugljeni", "carbohydrate", "carbs", "uh",
                    "masti", "fat"
                ]
                
                let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                let matched = observations.filter { observation in
                    guard let text = observation.topCandidates(1).first?.string.lowercased() else { return false }
                    return keywords.contains { text.contains($0) }
                }
                
                guard !matched.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                var union = matched[0].boundingBox
                for obs in matched.dropFirst() {
                    union = union.union(obs.boundingBox)
                }
                
                let expanded = expandNormalizedRect(union, by: 0.18)
                continuation.resume(returning: expanded)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["sr-RS", "en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func expandNormalizedRect(_ rect: CGRect, by factor: CGFloat) -> CGRect {
        let dx = rect.width * factor
        let dy = rect.height * factor
        let expanded = rect.insetBy(dx: -dx, dy: -dy)
        return CGRect(
            x: max(0, expanded.minX),
            y: max(0, expanded.minY),
            width: min(1, expanded.maxX) - max(0, expanded.minX),
            height: min(1, expanded.maxY) - max(0, expanded.minY)
        )
    }
    
    private func initializeCropIfNeeded(frame: CGRect) {
        guard frame.width > 0, frame.height > 0 else { return }
        imageFrame = frame
        
        let currentlyInvalid =
            cropRect == .zero ||
            !imageFrame.contains(CGPoint(x: cropRect.minX, y: cropRect.minY)) ||
            !imageFrame.contains(CGPoint(x: cropRect.maxX, y: cropRect.maxY))
        
        if currentlyInvalid {
            cropRect = CGRect(
                x: frame.minX + frame.width * 0.1,
                y: frame.minY + frame.height * 0.2,
                width: frame.width * 0.8,
                height: frame.height * 0.6
            )
        }
    }
    
    private func resizeFromTopLeft(to point: CGPoint) {
        let maxX = cropRect.maxX
        let maxY = cropRect.maxY
        let newMinX = min(max(point.x, imageFrame.minX), maxX - minCropSize)
        let newMinY = min(max(point.y, imageFrame.minY), maxY - minCropSize)
        cropRect = CGRect(x: newMinX, y: newMinY, width: maxX - newMinX, height: maxY - newMinY)
    }
    
    private func resizeFromTopRight(to point: CGPoint) {
        let minX = cropRect.minX
        let maxY = cropRect.maxY
        let newMaxX = max(min(point.x, imageFrame.maxX), minX + minCropSize)
        let newMinY = min(max(point.y, imageFrame.minY), maxY - minCropSize)
        cropRect = CGRect(x: minX, y: newMinY, width: newMaxX - minX, height: maxY - newMinY)
    }
    
    private func resizeFromBottomLeft(to point: CGPoint) {
        let maxX = cropRect.maxX
        let minY = cropRect.minY
        let newMinX = min(max(point.x, imageFrame.minX), maxX - minCropSize)
        let newMaxY = max(min(point.y, imageFrame.maxY), minY + minCropSize)
        cropRect = CGRect(x: newMinX, y: minY, width: maxX - newMinX, height: newMaxY - minY)
    }
    
    private func resizeFromBottomRight(to point: CGPoint) {
        let minX = cropRect.minX
        let minY = cropRect.minY
        let newMaxX = max(min(point.x, imageFrame.maxX), minX + minCropSize)
        let newMaxY = max(min(point.y, imageFrame.maxY), minY + minCropSize)
        cropRect = CGRect(x: minX, y: minY, width: newMaxX - minX, height: newMaxY - minY)
    }
}

private extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext() ?? self
        UIGraphicsEndImageContext()
        return normalized
    }
}
