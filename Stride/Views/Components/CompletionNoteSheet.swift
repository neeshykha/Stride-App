import SwiftUI

struct CompletionNoteSheet: View {
    let itemName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var noteText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text("Completion Note")
                    .font(.headline)
                Spacer()
            }

            // Item name
            Text(itemName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Note field
            TextField("What did you do? (e.g., 185 lbs x 3 sets)", text: $noteText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .focused($isFocused)

            // Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let trimmed = noteText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(noteText.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            isFocused = true
        }
    }
}
