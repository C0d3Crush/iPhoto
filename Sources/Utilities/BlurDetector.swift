import Accelerate
import CoreGraphics

struct BlurDetector {
    static let defaultThreshold: Double = 120.0

    // Laplacian-Varianz: höher = schärfer, niedriger = unscharf.
    static func score(from image: CGImage) -> Double {
        let maxDim = 512
        let w0 = image.width, h0 = image.height
        guard w0 > 0, h0 > 0 else { return 0 }

        let scale = min(1.0, Double(maxDim) / Double(max(w0, h0)))
        let w = max(1, Int(Double(w0) * scale))
        let h = max(1, Int(Double(h0) * scale))
        let n = w * h

        var gray = [UInt8](repeating: 0, count: n)
        guard let ctx = CGContext(
            data: &gray, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        var floatBuf = [Float](repeating: 0, count: n)
        vDSP_vfltu8(gray, 1, &floatBuf, 1, vDSP_Length(n))

        let kernel: [Float] = [0, 1, 0,
                               1,-4, 1,
                               0, 1, 0]
        var result = [Float](repeating: 0, count: n)
        floatBuf.withUnsafeMutableBufferPointer { srcPtr in
            result.withUnsafeMutableBufferPointer { dstPtr in
                var srcBuf = vImage_Buffer(data: srcPtr.baseAddress!, height: UInt(h), width: UInt(w),
                                           rowBytes: w * MemoryLayout<Float>.size)
                var dstBuf = vImage_Buffer(data: dstPtr.baseAddress!, height: UInt(h), width: UInt(w),
                                           rowBytes: w * MemoryLayout<Float>.size)
                vImageConvolve_PlanarF(&srcBuf, &dstBuf, nil, 0, 0,
                                       kernel, 3, 3, 0.0,
                                       vImage_Flags(kvImageEdgeExtend))
            }
        }

        var mean: Float = 0
        vDSP_meanv(result, 1, &mean, vDSP_Length(n))
        var negMean = -mean
        vDSP_vsadd(result, 1, &negMean, &result, 1, vDSP_Length(n))
        vDSP_vsq(result, 1, &result, 1, vDSP_Length(n))
        var variance: Float = 0
        vDSP_meanv(result, 1, &variance, vDSP_Length(n))

        return Double(variance)
    }
}
