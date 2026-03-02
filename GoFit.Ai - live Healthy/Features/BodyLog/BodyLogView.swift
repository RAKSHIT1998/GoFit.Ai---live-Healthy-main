//
//  BodyLogView.swift
//  GoFit.Ai - live Healthy
//
//  Body weight + progress photo log accessible from Meal History
//

import SwiftUI
import UIKit

// MARK: - Body Log Sheet
struct BodyLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var bodyLog = BodyLogManager.shared
    
    @State private var weight: String = ""
    @State private var note: String = ""
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Design.Spacing.xl) {
                        // Photo Section
                        photoSection
                        
                        // Weight Input
                        weightSection
                        
                        // Note
                        noteSection
                        
                        // Save Button
                        saveButton
                    }
                    .padding(Design.Spacing.lg)
                }
            }
            .navigationTitle("Log Body Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraImagePicker(image: $capturedImage, cameraDevice: .front)
            }
            .sheet(isPresented: $showPhotoLibrary) {
                PhotoLibraryPicker(image: $capturedImage)
            }
            .onAppear {
                if let latest = bodyLog.latestWeight {
                    weight = String(format: "%.1f", latest)
                }
            }
        }
    }
    
    // MARK: - Photo Section
    private var photoSection: some View {
        VStack(spacing: Design.Spacing.md) {
            Text("Progress Photo")
                .font(Design.Typography.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let image = capturedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    Button {
                        capturedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .padding(12)
                }
            } else {
                HStack(spacing: Design.Spacing.md) {
                    Button {
                        HapticManager.shared.mediumTap()
                        showCamera = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Design.Colors.primary)
                                .clipShape(Circle())
                            Text("Take Photo")
                                .font(Design.Typography.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.Spacing.lg)
                        .background(Design.Colors.cardBackground)
                        .cornerRadius(16)
                    }
                    .buttonStyle(SmoothButtonStyle())
                    
                    Button {
                        HapticManager.shared.mediumTap()
                        showPhotoLibrary = true
                    } label: {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Design.Colors.accent)
                                .clipShape(Circle())
                            Text("Gallery")
                                .font(Design.Typography.caption)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Design.Spacing.lg)
                        .background(Design.Colors.cardBackground)
                        .cornerRadius(16)
                    }
                    .buttonStyle(SmoothButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Weight Section
    private var weightSection: some View {
        VStack(spacing: Design.Spacing.sm) {
            Text("Body Weight")
                .font(Design.Typography.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Image(systemName: "scalemass.fill")
                    .font(.title2)
                    .foregroundColor(Design.Colors.primary)
                
                TextField("Enter weight", text: $weight)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("kg")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(Design.Spacing.md)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            
            // Weight trend hint
            if let change = bodyLog.weeklyChange {
                HStack(spacing: 4) {
                    Image(systemName: change < 0 ? "arrow.down.right" : change > 0 ? "arrow.up.right" : "arrow.right")
                        .foregroundColor(change < 0 ? Design.Colors.success : change > 0 ? Design.Colors.calories : .secondary)
                    Text(String(format: "%+.1f kg this week", change))
                        .font(Design.Typography.caption)
                        .foregroundColor(change < 0 ? Design.Colors.success : change > 0 ? Design.Colors.calories : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - Note Section
    private var noteSection: some View {
        VStack(spacing: Design.Spacing.sm) {
            Text("Note (optional)")
                .font(Design.Typography.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("How are you feeling today?", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .padding(Design.Spacing.md)
                .background(Design.Colors.cardBackground)
                .cornerRadius(16)
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            guard let weightValue = Double(weight), weightValue > 0 else { return }
            isSaving = true
            
            bodyLog.addEntry(weight: weightValue, photo: capturedImage, note: note.isEmpty ? nil : note)
            
            isSaving = false
            dismiss()
        } label: {
            HStack {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Progress")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(Design.Spacing.md)
            .background(
                (Double(weight) ?? 0) > 0 ? Design.Colors.primary : Color.gray
            )
            .cornerRadius(Design.Radius.medium)
        }
        .disabled((Double(weight) ?? 0) <= 0 || isSaving)
        .buttonStyle(SmoothButtonStyle())
    }
}

// MARK: - Body Log History Card (for Meal History)
struct BodyLogCard: View {
    let date: Date
    @ObservedObject private var bodyLog = BodyLogManager.shared
    @State private var showingBodyLog = false
    
    var entries: [BodyLogEntry] {
        bodyLog.entriesForDate(date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            HStack {
                Image(systemName: "figure.arms.open")
                    .font(.title2)
                    .foregroundColor(Design.Colors.primary)
                
                Text("Body Progress")
                    .font(Design.Typography.title3)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    HapticManager.shared.lightTap()
                    showingBodyLog = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(Design.Colors.primary)
                }
            }
            
            if entries.isEmpty {
                Button {
                    HapticManager.shared.lightTap()
                    showingBodyLog = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(Design.Colors.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Log your body progress")
                                .font(Design.Typography.body)
                                .foregroundColor(.primary)
                            Text("Add weight & progress photo")
                                .font(Design.Typography.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding(Design.Spacing.md)
                    .background(Design.Colors.primary.opacity(0.08))
                    .cornerRadius(12)
                }
                .buttonStyle(SmoothButtonStyle())
            } else {
                ForEach(entries) { entry in
                    bodyEntryRow(entry)
                }
            }
        }
        .padding(Design.Spacing.md)
        .cardStyle()
        .padding(.horizontal, Design.Spacing.md)
        .sheet(isPresented: $showingBodyLog) {
            BodyLogSheet()
        }
    }
    
    private func bodyEntryRow(_ entry: BodyLogEntry) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let filename = entry.photoFilename, let image = bodyLog.loadPhoto(filename: filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "scalemass.fill")
                    .font(.title2)
                    .foregroundColor(Design.Colors.primary)
                    .frame(width: 56, height: 56)
                    .background(Design.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.formattedWeight)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let note = entry.note {
                    Text(note)
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Text(entry.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(Design.Spacing.sm)
        .background(Design.Colors.cardBackground)
        .cornerRadius(10)
    }
}

// MARK: - Photo Library Picker
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: PhotoLibraryPicker
        
        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
