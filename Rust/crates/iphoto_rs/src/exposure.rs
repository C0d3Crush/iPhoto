// Histogramm-basierte Über-/Unterbelichtungs-Erkennung.
// Repliziert ExposureDetector.swift exakt: Integer-Histogramm, gleiche Schwellenwerte.

pub fn analyze(
    pixels: &[u8],
    shadow_clip: u8,
    highlight_clip: u8,
    out_under: &mut f64,
    out_over: &mut f64,
) {
    let mut histogram = [0u64; 256];
    for &p in pixels {
        histogram[p as usize] += 1;
    }
    let total = pixels.len() as f64;
    if total == 0.0 {
        *out_under = 0.0;
        *out_over = 0.0;
        return;
    }
    // Swift: histogram[0..<shadow]        → exklusiv → Bins 0..shadow_clip-1
    // Swift: histogram[highlight+1..<256] → exklusiv → Bins highlight_clip+1..255
    let under: u64 = histogram[..(shadow_clip as usize)].iter().sum();
    let over: u64 = histogram[(highlight_clip as usize + 1)..].iter().sum();
    *out_under = under as f64 / total;
    *out_over = over as f64 / total;
}
