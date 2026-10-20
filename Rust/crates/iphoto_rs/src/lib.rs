mod blur;
mod exposure;
mod hotpixel;
mod oklab;
mod phash;

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
