import SwiftUI

struct AnywhereEasterEggView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .frame(maxWidth: .infinity, alignment: .trailing)

            Image("AnytimeAnywhereCover")
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Album cover showing Frieren beneath a meteor shower")
                .frame(maxHeight: .infinity)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.04, green: 0.05, blue: 0.10).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
