// Laplacian-Varianz zur Schärfemessung.
// Repliziert BlurDetector.swift: 3×3 Laplacian [0,1,0;1,-4,1;0,1,0],
// zwei-Durchgänge Varianz (mean-centering, dann mean of squares).

pub fn score(pixels: &[u8], width: u32, height: u32) -> f64 {
    let w = width as usize;
    let h = height as usize;
    if w < 3 || h < 3 || pixels.len() < w * h {
        return 0.0;
    }
    // Laplacian auf inneren Pixels (Rand überspringen — wie vImage Edge-Extend)
    let inner = (w - 2) * (h - 2);
    let mut response = Vec::with_capacity(inner);
    for y in 1..(h - 1) {
        for x in 1..(w - 1) {
            let c  = pixels[y * w + x] as f64;
            let n  = pixels[(y - 1) * w + x] as f64;
            let s  = pixels[(y + 1) * w + x] as f64;
            let e  = pixels[y * w + x + 1] as f64;
            let ew = pixels[y * w + x - 1] as f64;
            let v = n + s + e + ew - 4.0 * c;
            response.push(v);
        }
    }
    // Varianz: zwei Durchgänge — identisch zu Swift (population variance / N)
    let mean = response.iter().sum::<f64>() / response.len() as f64;
    let variance = response.iter().map(|&v| (v - mean) * (v - mean)).sum::<f64>()
        / response.len() as f64;
    variance
}
