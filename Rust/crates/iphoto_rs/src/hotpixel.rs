use rayon::prelude::*;

#[repr(C)]
pub struct HotPixel {
    pub x: u32,
    pub y: u32,
    pub value: f32,
}

// Akkumuliert ein RGBA-U8-Frame in den Float-Summenpuffer (Rec.709 Luminanz).
// Parallelisiert mit rayon — ein Schreib-Zugriff pro Element, kein Race.
pub fn accumulate(sum: &mut [f32], rgba: &[u8]) {
    sum.par_iter_mut()
        .zip(rgba.par_chunks_exact(4))
        .for_each(|(s, px)| {
            let r = px[0] as f32;
            let g = px[1] as f32;
            let b = px[2] as f32;
            *s += 0.2126 * r + 0.7152 * g + 0.0722 * b;
        });
}

// Findet Hot-Pixel: mean_frame[i] > threshold.
// Gibt heap-allokierten Vec als raw Pointer zurück — Aufrufer MUSS free() aufrufen.
pub fn find(mean_frame: &[f32], width: u32, threshold: f32) -> Vec<HotPixel> {
    let w = width as usize;
    let mut result: Vec<HotPixel> = mean_frame
        .iter()
        .enumerate()
        .filter(|(_, &v)| v > threshold)
        .map(|(i, &v)| HotPixel {
            x: (i % w) as u32,
            y: (i / w) as u32,
            value: v,
        })
        .collect();
    result.sort_by(|a, b| b.value.partial_cmp(&a.value).unwrap_or(std::cmp::Ordering::Equal));
    result
}

// Zwei-Durchgänge Mittelwert + Standardabweichung (population std).
pub fn mean_std(values: &[f32]) -> (f32, f32) {
    if values.is_empty() {
        return (0.0, 0.0);
    }
    let mean = values.iter().sum::<f32>() / values.len() as f32;
    let variance = values.iter().map(|&v| (v - mean) * (v - mean)).sum::<f32>()
        / values.len() as f32;
    (mean, variance.sqrt())
}
