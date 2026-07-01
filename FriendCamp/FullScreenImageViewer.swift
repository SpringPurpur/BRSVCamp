import SwiftUI

// Afișează o poză întreagă (fără decupare), pe fundal negru — deschisă la tap pe un thumbnail.
struct FullScreenImageViewer: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView().tint(.white)
            }
            .onTapGesture { dismiss() }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, .black.opacity(0.4))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}
