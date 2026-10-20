/// OkLab-based Vibrance and Hue-rotation LUT builder.
/// Reference: Björn Ottosson (2020) — https://bottosson.github.io/posts/oklab/

#[inline(always)]
fn srgb_to_linear(c: f32) -> f32 {
    if c <= 0.04045 {
        c / 12.92
    } else {
        ((c + 0.055) / 1.055).powf(2.4)
    }
}

#[inline(always)]
fn linear_to_srgb(c: f32) -> f32 {
    let g = if c <= 0.0031308 {
        12.92 * c
    } else {
        1.055 * c.powf(1.0 / 2.4) - 0.055
    };
    g.clamp(0.0, 1.0)
}

#[inline(always)]
fn rgb_to_oklab(r: f32, g: f32, b: f32) -> (f32, f32, f32) {
    let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
    let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
    let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

    let l_ = l.cbrt();
    let m_ = m.cbrt();
    let s_ = s.cbrt();

    let ll =  0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_;
    let a  =  1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_;
    let bb =  0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_;
    (ll, a, bb)
}

#[inline(always)]
fn oklab_to_rgb(ll: f32, a: f32, bb: f32) -> (f32, f32, f32) {
    let l_ = ll + 0.3963377774 * a + 0.2158037573 * bb;
    let m_ = ll - 0.1055613458 * a - 0.0638541728 * bb;
    let s_ = ll - 0.0894841775 * a - 1.2914855480 * bb;

    let l = l_ * l_ * l_;
    let m = m_ * m_ * m_;
    let s = s_ * s_ * s_;

    let r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    let b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
    (r, g, b)
}

/// Builds a 3D LUT of size³ entries × 4 floats (RGBA).
/// Layout: out[((bi*size + gi)*size + ri)*4 ..] = [r, g, b, 1.0]
pub fn build_lut(vibrance: f32, hue_deg: f32, out: &mut [f32], size: usize) {
    let hue_rad = hue_deg * std::f32::consts::PI / 180.0;
    let cos_h = hue_rad.cos();
    let sin_h = hue_rad.sin();

    for bi in 0..size {
        for gi in 0..size {
            for ri in 0..size {
                let r_in = ri as f32 / (size - 1) as f32;
                let g_in = gi as f32 / (size - 1) as f32;
                let b_in = bi as f32 / (size - 1) as f32;

                // sRGB → linear
                let rl = srgb_to_linear(r_in);
                let gl = srgb_to_linear(g_in);
                let bl = srgb_to_linear(b_in);

                // linear RGB → OkLab
                let (ll, mut a, mut b_ok) = rgb_to_oklab(rl, gl, bl);

                // Chroma in OkLCh
                let c = (a * a + b_ok * b_ok).sqrt();

                // Apply vibrance: selective chroma boost
                if vibrance != 0.0 && c > 1e-6 {
                    let c_max = 0.4_f32;
                    let factor = (1.0 + vibrance * (1.0 - c / c_max)).max(0.0);
                    a     *= factor;
                    b_ok  *= factor;
                }

                // Apply hue rotation in OkLCh
                if hue_deg != 0.0 && c > 1e-6 {
                    let a_new =  a * cos_h - b_ok * sin_h;
                    let b_new =  a * sin_h + b_ok * cos_h;
                    a     = a_new;
                    b_ok  = b_new;
                }

                // OkLab → linear RGB
                let (r_lin, g_lin, b_lin) = oklab_to_rgb(ll, a, b_ok);

                // linear → sRGB with clamping
                let r_out = linear_to_srgb(r_lin);
                let g_out = linear_to_srgb(g_lin);
                let b_out = linear_to_srgb(b_lin);

                let idx = ((bi * size + gi) * size + ri) * 4;
                out[idx]     = r_out;
                out[idx + 1] = g_out;
                out[idx + 2] = b_out;
                out[idx + 3] = 1.0;
            }
        }
    }
}
