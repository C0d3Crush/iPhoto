import CoreImage

// CIKL kernels (deprecated-but-functional on macOS 11–15).
// CA: scales the R channel outward and B inward from the image center,
// correcting lateral chromatic aberration without any custom Metal compilation.
// Distortion: radial polynomial warp, k1 > 0 corrects barrel, k1 < 0 corrects pincushion.
enum LensFilters {

    static let caKernel: CIKernel? = CIKernel(source: """
        kernel vec4 caCorrection(__sample image, float amount) {
            vec4  ext    = samplerExtent(image);
            vec2  center = vec2(ext.x + ext.z * 0.5, ext.y + ext.w * 0.5);
            vec2  off    = destCoord() - center;
            vec2  rCoord = center + off * (1.0 + amount * 0.0015);
            vec2  bCoord = center + off * (1.0 - amount * 0.0015);
            float r = sample(image, samplerTransform(image, rCoord)).r;
            float g = sample(image, samplerTransform(image, destCoord())).g;
            float b = sample(image, samplerTransform(image, bCoord)).b;
            float a = sample(image, samplerTransform(image, destCoord())).a;
            return vec4(r, g, b, a);
        }
        """)

    static let distortKernel: CIWarpKernel? = CIWarpKernel(source: """
        kernel vec2 lensDistort(vec4 extent, float k1) {
            vec2  center = vec2(extent.x + extent.z * 0.5,
                                extent.y + extent.w * 0.5);
            vec2  half   = vec2(extent.z, extent.w) * 0.5;
            vec2  p      = (destCoord() - center) / half;
            float r2     = dot(p, p);
            return center + p * (1.0 + k1 * r2) * half;
        }
        """)
}
