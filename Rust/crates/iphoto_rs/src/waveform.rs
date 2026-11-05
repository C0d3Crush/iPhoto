// Luma-Histogramm + Waveform-Akkumulator.
// Ersetzt den verschachtelten Swift-Loop in AnalysisEngine.swift.
// BT.709: luma = 0.2126·R + 0.7152·G + 0.0722·B
// Integer-Annäherung: (R·218 + G·732 + B·74 + 512) >> 10 (max-Fehler: ±1 Bin)

pub fn accumulate(
    rgba: &[u8],
    w: usize,
    h: usize,
    out_h: usize,
    luma_hist: &mut [u32], // 256 Bins
    luma_acc: &mut [f32],  // w × out_h
    r_acc: &mut [f32],     // w × out_h
    g_acc: &mut [f32],     // w × out_h
    b_acc: &mut [f32],     // w × out_h
) {
    let oh1 = out_h - 1;
    for row in 0..h {
        let row_base = row * w * 4;
        for col in 0..w {
            let base = row_base + col * 4;
            let rv = rgba[base] as u32;
            let gv = rgba[base + 1] as u32;
            let bv = rgba[base + 2] as u32;

            // BT.709 luma — integer-skaliert auf 0..255
            let luma = ((rv * 218 + gv * 732 + bv * 74 + 512) >> 10).min(255) as usize;
            luma_hist[luma] += 1;

            // Waveform y: heller → kleinerer Index (oben), dunkler → größerer (unten)
            let y_luma = oh1 - (luma * oh1 / 255);
            luma_acc[y_luma * w + col] += 1.0;

            let y_r = oh1 - (rv as usize * oh1 / 255);
            r_acc[y_r * w + col] += 1.0;

            let y_g = oh1 - (gv as usize * oh1 / 255);
            g_acc[y_g * w + col] += 1.0;

            let y_b = oh1 - (bv as usize * oh1 / 255);
            b_acc[y_b * w + col] += 1.0;
        }
    }
}
