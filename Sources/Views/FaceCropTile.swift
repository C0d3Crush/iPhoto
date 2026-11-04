import SwiftUI
import AppKit
import CoreGraphics
import ImageIO

// Zeigt einen ausgeschnittenen Gesichts-Crop aus einem FaceRecord.
// Lädt das Thumbnail des Originalbilds lazy und schneidet die bbox-Region aus.

struct FaceCropTile: View {
    let face: FaceRecord
    let size: CGFloat

    @State private var cropImage: NSImage? = nil

    var body: some View {
        Group {
            if let img = cropImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(NSColor.separatorColor).opacity(0.3))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "person.crop.rectangle")
                            .foregroundColor(.secondary)
                            .font(.system(size: size * 0.3))
                    )
            }
        }
        .onAppear { loadCrop() }
    }

    private func loadCrop() {
        let path = face.imagePath
        let bbox = face.bbox
        let targetSize = size * 2  // 2× für Retina
        DispatchQueue.global(qos: .userInitiated).async {
            guard let img = cropFace(path: path, bbox: bbox, targetSize: targetSize) else { return }
            DispatchQueue.main.async { cropImage = img }
        }
    }

    private func cropFace(path: String, bbox: CGRect, targetSize: CGFloat) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: Int(targetSize * 2),
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }

        let w = CGFloat(thumb.width)
        let h = CGFloat(thumb.height)

        // bbox ist top-left normalisiert — in Pixel umrechnen
        let expand: CGFloat = 0.15  // 15% Rand um das Gesicht
        let fx = max(0, (bbox.origin.x - expand * bbox.width) * w)
        let fy = max(0, (bbox.origin.y - expand * bbox.height) * h)
        let fw = min(w - fx, (bbox.width  + 2 * expand * bbox.width) * w)
        let fh = min(h - fy, (bbox.height + 2 * expand * bbox.height) * h)

        guard fw > 0, fh > 0,
              let cropped = thumb.cropping(to: CGRect(x: fx, y: fy, width: fw, height: fh)) else {
            return nil
        }
        return NSImage(cgImage: cropped, size: NSSize(width: fw, height: fh))
    }
}
