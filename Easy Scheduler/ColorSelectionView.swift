// Create a new SwiftUI view for color selection.
import SwiftUI

struct ColorSelectionView: View {
    @Binding var backgroundColor: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Select Background Color")
                    .font(.headline)
                ColorPicker("Background", selection: $backgroundColor)
                    .padding(.horizontal)
                Spacer()
            }
            .padding()
            .navigationTitle("Background")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ColorSelectionView(backgroundColor: .constant(.blue))
}
