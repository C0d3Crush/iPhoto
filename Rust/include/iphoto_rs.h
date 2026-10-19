#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// ── BlurDetector ─────────────────────────────────────────────────────────────
// Grayscale U8, stride == width. Gibt Laplacian-Varianz zurück (höher = schärfer).
double iphoto_blur_score(const uint8_t *pixels, uint32_t width, uint32_t height);

// ── ExposureDetector ─────────────────────────────────────────────────────────
void iphoto_exposure_analyze(
    const uint8_t *pixels, uint32_t width, uint32_t height,
    uint8_t shadow_clip, uint8_t highlight_clip,
    double *out_under_ratio, double *out_over_ratio);

// ── PerceptualHash ────────────────────────────────────────────────────────────
// pixels_9x9: exakt 81 Bytes (9×9 Grayscale, von Swift bereits downgeskaliert).
// Bit-Reihenfolge identisch zu QualityAssessor.swift — SQLite-Katalog-kompatibel.
void iphoto_dhash_pair(
    const uint8_t *pixels_9x9,
    uint64_t *out_hash_h,
    uint64_t *out_hash_v);

// ── HotPixelAnalyzer ─────────────────────────────────────────────────────────
// Akkumuliert ein RGBA-U8-Frame in den Float-Summenpuffer (Rec.709, rayon-parallel).
void iphoto_hotpixel_accumulate(float *sum, const uint8_t *rgba_pixels, uint32_t count);

typedef struct { uint32_t x; uint32_t y; float value; } IPhotoHotPixel;

// Gibt heap-allokierten Array zurück — MUSS mit iphoto_hotpixel_free freigegeben werden.
IPhotoHotPixel *iphoto_hotpixel_find(
    const float *mean_frame, uint32_t count, uint32_t width,
    float threshold, uint32_t *out_count);

void iphoto_hotpixel_free(IPhotoHotPixel *ptr, uint32_t count);

void iphoto_mean_std(const float *values, uint32_t count,
                     float *out_mean, float *out_std);

#ifdef __cplusplus
}
#endif
