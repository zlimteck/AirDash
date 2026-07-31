import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let profileContent: String

    @Environment(\.dismiss) private var dismiss
    private let qrImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = generateQRCode() {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    ContentUnavailableView("qr.error", systemImage: "qrcode")
                }

                Text("qr.instructions")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("qr.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { dismiss() }
                }
            }
        }
    }

    private func generateQRCode() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(profileContent.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
