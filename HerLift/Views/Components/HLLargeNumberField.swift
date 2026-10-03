import SwiftUI

/// A big number box with its label above and its unit at the end, for weights and reps. When it is not editable
/// it only shows the number.
struct HLLargeNumberField: View {
    let title: String
    @Binding var text: String
    let unit: String
    var hasError = false
    var keyboard: UIKeyboardType = .decimalPad
    var isEditable = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote.weight(.medium)).foregroundStyle(HerLiftTheme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if isEditable {
                    TextField("", text: $text, prompt: Text("0").foregroundStyle(HerLiftTheme.secondaryText))
                        .font(.largeTitle.bold().monospacedDigit()).foregroundStyle(HerLiftTheme.text)
                        .keyboardType(keyboard)
                } else {
                    Text(text).font(.largeTitle.bold().monospacedDigit()).foregroundStyle(HerLiftTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(unit).font(.subheadline).foregroundStyle(HerLiftTheme.secondaryText)
            }
            .padding(.horizontal, 16).frame(minHeight: 72)
            .background(HerLiftTheme.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                if hasError { RoundedRectangle(cornerRadius: 14).strokeBorder(HerLiftTheme.text, lineWidth: 2) }
            }
        }
        .accessibilityElement(children: .combine)
        // A tap selects the number already there, so typing replaces it instead of adding to it.
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { note in
            guard let field = note.object as? UITextField else { return }
            DispatchQueue.main.async { field.selectAll(nil) }
        }
    }
}

#Preview("Large number field") {
    @Previewable @State var weight = "30"
    @Previewable @State var reps = "0"
    HStack(spacing: 12) {
        HLLargeNumberField(title: "Weight", text: $weight, unit: "kg")
        HLLargeNumberField(title: "Reps", text: $reps, unit: "reps", hasError: true)
    }
    .padding(20).background(HerLiftTheme.background)
}

#Preview("Large number field · display only") {
    @Previewable @State var weight = "30"
    @Previewable @State var reps = "12"
    HStack(spacing: 12) {
        HLLargeNumberField(title: "Weight", text: $weight, unit: "kg", isEditable: false)
        HLLargeNumberField(title: "Reps", text: $reps, unit: "reps", isEditable: false)
    }
    .padding(20).background(HerLiftTheme.background)
}
