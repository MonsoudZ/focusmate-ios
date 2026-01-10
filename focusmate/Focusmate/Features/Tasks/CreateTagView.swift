//
//  CreateTagView.swift
//  focusmate
//
//  Created by Monsoud Zanaty on 1/7/26.
//


import SwiftUI

struct CreateTagView: View {
    let tagService: TagService
    var onCreated: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var selectedColor: String = "blue"
    @State private var isLoading = false
    @State private var error: FocusmateError?
    
    private let colors = ["blue", "green", "orange", "red", "purple", "pink", "teal", "yellow", "gray"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tag Name") {
                    TextField("Name", text: $name)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Circle()
                                .fill(colorFor(color))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                )
                                .onTapGesture {
                                    HapticManager.selection()
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Preview
                Section("Preview") {
                    HStack {
                        Circle()
                            .fill(colorFor(selectedColor))
                            .frame(width: 8, height: 8)
                        Text(name.isEmpty ? "Tag Name" : name)
                            .font(DesignSystem.Typography.caption1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(colorFor(selectedColor).opacity(0.2))
                    .cornerRadius(16)
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createTag() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
            .errorBanner($error)
        }
    }
    
    private func colorFor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "yellow": return .yellow
        case "gray": return .gray
        default: return .blue
        }
    }
    
    private func createTag() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await tagService.createTag(name: trimmedName, color: selectedColor)
            HapticManager.success()
            onCreated?()
            dismiss()
        } catch let err as FocusmateError {
            error = err
            HapticManager.error()
        } catch {
            self.error = .custom("CREATE_TAG_ERROR", error.localizedDescription)
            HapticManager.error()
        }
    }
}