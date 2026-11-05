// Dualer dHash (horizontal + vertikal) aus 9×9 Graustufen-Raster.
// Bit-Reihenfolge MUSS identisch zur Swift-Implementierung sein —
// bereits gecachte pHash-Werte in SQLite dürfen nicht ungültig werden.

pub fn dhash_pair(pixels_9x9: &[u8]) -> (u64, u64) {
    assert!(pixels_9x9.len() >= 81, "dhash_pair erwartet exakt 81 Bytes (9×9)");
    let side = 9usize;
    let mut hash_h: u64 = 0;
    let mut bit_h = 0u32;
    for y in 0..8 {
        for x in 0..8 {
            if pixels_9x9[y * side + x] > pixels_9x9[y * side + x + 1] {
                hash_h |= 1u64 << bit_h;
            }
            bit_h += 1;
        }
    }
    let mut hash_v: u64 = 0;
    let mut bit_v = 0u32;
    for x in 0..8 {
        for y in 0..8 {
            if pixels_9x9[y * side + x] > pixels_9x9[(y + 1) * side + x] {
                hash_v |= 1u64 << bit_v;
            }
            bit_v += 1;
        }
    }
    (hash_h, hash_v)
}
