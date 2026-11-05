mod blur;
mod exposure;
mod hotpixel;
mod oklab;
mod phash;
mod similarity;
mod waveform;

use hotpixel::HotPixel;

// ── BlurDetector ──────────────────────────────────────────────────────────────

#[no_mangle]
pub extern "C" fn iphoto_blur_score(
    pixels: *const u8,
    width: u32,
    height: u32,
) -> f64 {
    if pixels.is_null() { return 0.0; }
    let len = (width as usize) * (height as usize);
    let slice = unsafe { std::slice::from_raw_parts(pixels, len) };
    blur::score(slice, width, height)
}

// ── ExposureDetector ──────────────────────────────────────────────────────────

#[no_mangle]
pub extern "C" fn iphoto_exposure_analyze(
    pixels: *const u8,
    width: u32,
    height: u32,
    shadow_clip: u8,
    highlight_clip: u8,
    out_under: *mut f64,
    out_over: *mut f64,
) {
    if pixels.is_null() || out_under.is_null() || out_over.is_null() { return; }
    let len = (width as usize) * (height as usize);
    let slice = unsafe { std::slice::from_raw_parts(pixels, len) };
    let mut under = 0.0f64;
    let mut over = 0.0f64;
    exposure::analyze(slice, shadow_clip, highlight_clip, &mut under, &mut over);
    unsafe { *out_under = under; *out_over = over; }
}

// ── PerceptualHash ────────────────────────────────────────────────────────────

#[no_mangle]
pub extern "C" fn iphoto_dhash_pair(
    pixels_9x9: *const u8,
    out_hash_h: *mut u64,
    out_hash_v: *mut u64,
) {
    if pixels_9x9.is_null() || out_hash_h.is_null() || out_hash_v.is_null() { return; }
    let slice = unsafe { std::slice::from_raw_parts(pixels_9x9, 81) };
    let (h, v) = phash::dhash_pair(slice);
    unsafe { *out_hash_h = h; *out_hash_v = v; }
}

// ── HotPixelAnalyzer ──────────────────────────────────────────────────────────

#[no_mangle]
pub extern "C" fn iphoto_hotpixel_accumulate(
    sum: *mut f32,
    rgba_pixels: *const u8,
    count: u32,
) {
    if sum.is_null() || rgba_pixels.is_null() { return; }
    let n = count as usize;
    let sum_slice = unsafe { std::slice::from_raw_parts_mut(sum, n) };
    let rgba_slice = unsafe { std::slice::from_raw_parts(rgba_pixels, n * 4) };
    hotpixel::accumulate(sum_slice, rgba_slice);
}

#[no_mangle]
pub extern "C" fn iphoto_hotpixel_find(
    mean_frame: *const f32,
    count: u32,
    width: u32,
    threshold: f32,
    out_count: *mut u32,
) -> *mut HotPixel {
    if mean_frame.is_null() || out_count.is_null() { return std::ptr::null_mut(); }
    let slice = unsafe { std::slice::from_raw_parts(mean_frame, count as usize) };
    let mut result = hotpixel::find(slice, width, threshold);
    unsafe { *out_count = result.len() as u32; }
    let ptr = result.as_mut_ptr();
    std::mem::forget(result);
    ptr
}

#[no_mangle]
pub extern "C" fn iphoto_hotpixel_free(ptr: *mut HotPixel, count: u32) {
    if ptr.is_null() { return; }
    unsafe { drop(Vec::from_raw_parts(ptr, count as usize, count as usize)); }
}

// ── OkLab LUT ─────────────────────────────────────────────────────────────────

#[no_mangle]
pub extern "C" fn iphoto_oklab_lut(vibrance: f32, hue_deg: f32, out: *mut f32, size: u32) {
    if out.is_null() || size == 0 { return; }
    let n = (size as usize).pow(3) * 4;
    let slice = unsafe { std::slice::from_raw_parts_mut(out, n) };
    oklab::build_lut(vibrance, hue_deg, slice, size as usize);
}

#[no_mangle]
pub extern "C" fn iphoto_mean_std(
    values: *const f32,
    count: u32,
    out_mean: *mut f32,
    out_std: *mut f32,
) {
    if values.is_null() || out_mean.is_null() || out_std.is_null() { return; }
    let slice = unsafe { std::slice::from_raw_parts(values, count as usize) };
    let (mean, std) = hotpixel::mean_std(slice);
    unsafe { *out_mean = mean; *out_std = std; }
}

// ── WaveformAccumulator ───────────────────────────────────────────────────────

#[no_mangle]
pub extern "C" fn iphoto_waveform_accumulate(
    rgba: *const u8,
    w: u32,
    h: u32,
    out_h: u32,
    luma_hist: *mut u32, // 256 u32-Bins
    luma_acc: *mut f32,  // w × out_h
    r_acc: *mut f32,
    g_acc: *mut f32,
    b_acc: *mut f32,
) {
    if rgba.is_null() || luma_hist.is_null() || luma_acc.is_null()
        || r_acc.is_null() || g_acc.is_null() || b_acc.is_null()
    {
        return;
    }
    let ww = w as usize;
    let hh = h as usize;
    let oh = out_h as usize;
    let n_acc = ww * oh;
    let rgba_slice = unsafe { std::slice::from_raw_parts(rgba, ww * hh * 4) };
    let hist_slice = unsafe { std::slice::from_raw_parts_mut(luma_hist, 256) };
    let luma_slice = unsafe { std::slice::from_raw_parts_mut(luma_acc, n_acc) };
    let r_slice    = unsafe { std::slice::from_raw_parts_mut(r_acc,    n_acc) };
    let g_slice    = unsafe { std::slice::from_raw_parts_mut(g_acc,    n_acc) };
    let b_slice    = unsafe { std::slice::from_raw_parts_mut(b_acc,    n_acc) };
    waveform::accumulate(rgba_slice, ww, hh, oh, hist_slice, luma_slice, r_slice, g_slice, b_slice);
}

// ── pHash Seed-and-Pull Similarity ────────────────────────────────────────────

/// Seed-and-Pull Gruppensuche auf zwei orthogonalen dHash-Achsen.
/// Gibt heap-allokierten flachen u32-Array zurück (Gruppen-Separator = 0xFFFFFFFF).
/// MUSS mit iphoto_phash_groups_free freigegeben werden.
#[no_mangle]
pub extern "C" fn iphoto_phash_seed_pull_groups(
    hashes_h: *const u64,
    hashes_v: *const u64,
    count: u32,
    max_distance: u32,
    out_len: *mut u32,
) -> *mut u32 {
    if hashes_h.is_null() || hashes_v.is_null() || out_len.is_null() || count < 2 {
        if !out_len.is_null() { unsafe { *out_len = 0; } }
        return std::ptr::null_mut();
    }
    let n = count as usize;
    let h_slice = unsafe { std::slice::from_raw_parts(hashes_h, n) };
    let v_slice = unsafe { std::slice::from_raw_parts(hashes_v, n) };
    let mut result = similarity::seed_pull_groups(h_slice, v_slice, max_distance);
    unsafe { *out_len = result.len() as u32; }
    if result.is_empty() {
        return std::ptr::null_mut();
    }
    let ptr = result.as_mut_ptr();
    std::mem::forget(result);
    ptr
}

#[no_mangle]
pub extern "C" fn iphoto_phash_groups_free(ptr: *mut u32, len: u32) {
    if ptr.is_null() { return; }
    unsafe { drop(Vec::from_raw_parts(ptr, len as usize, len as usize)); }
}
