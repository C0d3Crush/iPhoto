// pHash Seed-and-Pull Gruppensuche — identische Semantik zu SimilarityGrouper.swift.
// Rayon parallelisiert den inneren Scan pro Seed; outer Loop bleibt sequenziell
// wegen des claimed[]-Zustands.
//
// Rückgabe: flaches Array u32 mit UINT32_MAX (0xFFFFFFFF) als Gruppen-Trennzeichen.
// Jede Gruppe hat Größe ≥ 2. Leer → leeres Vec.

use rayon::prelude::*;

pub fn seed_pull_groups(
    hashes_h: &[u64],
    hashes_v: &[u64],
    max_distance: u32,
) -> Vec<u32> {
    let n = hashes_h.len().min(hashes_v.len());
    if n < 2 {
        return Vec::new();
    }

    let mut claimed = vec![false; n];
    let mut flat: Vec<u32> = Vec::new();

    for i in 0..n {
        if claimed[i] {
            continue;
        }
        let hi = hashes_h[i];
        let vi = hashes_v[i];

        // Innerer Scan parallel: alle j > i die noch nicht claimed sind und matchen.
        // claimed[] wird nur nach dem collect() geschrieben — kein Race während des Scans.
        let matches: Vec<usize> = ((i + 1)..n)
            .into_par_iter()
            .filter(|&j| {
                !claimed[j]
                    && (hi ^ hashes_h[j]).count_ones() <= max_distance
                    && (vi ^ hashes_v[j]).count_ones() <= max_distance
            })
            .collect();

        if matches.is_empty() {
            continue;
        }

        claimed[i] = true;
        flat.push(i as u32);
        for &j in &matches {
            claimed[j] = true;
            flat.push(j as u32);
        }
        flat.push(u32::MAX); // Gruppen-Separator
    }

    flat
}
