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

// ── OkLab LUT ────────────────────────────────────────────────────────────────
// Baut einen 3D-LUT (size³ × 4 floats RGBA) mit Vibrance und Farbton-Rotation.
// vibrance: −1.0 … +1.0 (selektive Chroma-Verstärkung in OkLab)
// hue_deg:  −180 … +180 (Farbwinkel-Rotation in OkLCh, Grad)
// out muss size³×4 floats vorab allokiert sein.
void iphoto_oklab_lut(float vibrance, float hue_deg, float *out, uint32_t size);

// ── WaveformAccumulator ───────────────────────────────────────────────────────
// rgba: RGBA8-Pixel (scopeW × scopeH × 4 Bytes, premultiplied alpha wird ignoriert).
// out_h: Höhe der Waveform-Puffer (üblich 200). luma_hist muss 256 u32-Slots haben.
// luma_acc / r_acc / g_acc / b_acc: je w × out_h floats (vorab mit 0 befüllen).
void iphoto_waveform_accumulate(
    const uint8_t *rgba, uint32_t w, uint32_t h, uint32_t out_h,
    uint32_t *luma_hist,
    float *luma_acc, float *r_acc, float *g_acc, float *b_acc);

// ── pHash Seed-and-Pull Similarity ────────────────────────────────────────────
// Gibt heap-allokierten u32-Array zurück. Gruppen-Separator = 0xFFFFFFFF.
// Rückgabe NULL wenn count < 2 oder keine Gruppen gefunden.
// MUSS mit iphoto_phash_groups_free(ptr, out_len) freigegeben werden.
uint32_t *iphoto_phash_seed_pull_groups(
    const uint64_t *hashes_h, const uint64_t *hashes_v,
    uint32_t count, uint32_t max_distance,
    uint32_t *out_len);

void iphoto_phash_groups_free(uint32_t *ptr, uint32_t len);

#ifdef __cplusplus
}
#endif
