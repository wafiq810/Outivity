import SwiftUI
import UIKit

// MARK: - Thumbnail size constant
/// A minimal UIViewControllerRepresentable wrapper around UIImagePickerController
/// that presents the camera and returns captured image data via callbacks.
struct ActivityCameraView: UIViewControllerRepresentable {
    var onCapture: (_ displayData: Data, _ stripThumbData: Data) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ActivityCameraView
        init(parent: ActivityCameraView) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            defer { parent.onCancel() }
            guard let image = info[.originalImage] as? UIImage else { return }
            let display = image.resizedJPEG(maxLongEdge: 1024, quality: 0.85)    // carousel
            let thumb   = image.squareThumbnailJPEG(side: 300, quality: 0.5)    // strip/list

            if let display, let thumb {
                parent.onCapture(display, thumb)
            }

        }
    }
}
private extension UIImage {
    func resizedJPEG(maxLongEdge: CGFloat, quality: CGFloat) -> Data? {
        let w = size.width, h = size.height
        let longEdge = max(w, h)
        guard longEdge > maxLongEdge else { return jpegData(compressionQuality: quality) }

        let scale = maxLongEdge / longEdge
        let newSize = CGSize(width: w * scale, height: h * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let img = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return img.jpegData(compressionQuality: quality)
    }

    func squareThumbnailJPEG(side: CGFloat, quality: CGFloat) -> Data? {
        let cropFactor: CGFloat = 3
        let w = size.width, h = size.height
        let s = min(w, h)
        let crop = CGRect(x: (w - s)/cropFactor, y: (h - s)/cropFactor, width: s, height: s)

        guard let cg = self.cgImage?.cropping(to: crop) else {
            return resizedJPEG(maxLongEdge: side, quality: quality)
        }

        let cropped = UIImage(cgImage: cg, scale: scale, orientation: imageOrientation)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let img = renderer.image { _ in
            cropped.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return img.jpegData(compressionQuality: quality)
    }
}
