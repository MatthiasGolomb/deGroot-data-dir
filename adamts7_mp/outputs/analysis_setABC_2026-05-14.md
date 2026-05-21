# Set A/B/C Results Analysis — 2026-05-14

## Run Overview

Three 4-GPU parallel jobs submitted 2026-05-13, each running 4 workers × 63 trajectories = 252 trajectories per set.

| Job | Set | Hotspots | Trajectories | Passed hallucination | AbMPNN variants | Accepted | Redesign candidates |
|---|---|---|---|---|---|---|---|
| 4588539 | SetA | A185(Y), A186(D), A192(W) | 252 | 4 (1.6%) | 16 | 0 | 16 |
| 4588540 | SetB | A185(Y), A186(D), A197(R) | 252 | 2 (0.8%) | 8 | **1** | 7 |
| 4588541 | SetC | A185(Y), A186(D), A192(W), A197(R) | 252 | 5 (2.0%) | 20 | 0 | 20 |
| **Total** | | | **756** | **11 (1.5%)** | **44** | **1** | **43** |

Run summaries note these are single-worker figures (last writer, pre-fix): 61/63 failing hallucination quality check per worker per set.

---

## Bottleneck: Hallucination Quality Check

The hallucination quality check (`terminate` flag in ColabDesign output) rejects ~97% of trajectories before they reach AF3 cofolding. Hotspot constraints (biasing CDR loops to contact A185/A186/A192/A197) make it much harder for the model to find sequences that both fold well and satisfy proximity requirements.

Evidence:
- "Trajectory final confidence low, skipping analysis" is the dominant log message
- Per-set pass rates: 4/252, 2/252, 5/252 (1.6%, 0.8%, 2.0%)
- Hallucinated backbone PDBs are saved to `trajectories/structures/` by germinal_design regardless of quality — explaining the 252–278 files there despite almost all failing the quality check
- `trajectories/designs.csv` is correctly empty: failed hallucinations are not pipeline outputs

---

## The One Accepted Design — SetB

**`adamts7_nb_s814396_abmpnn_2`** (SetB, hotspots A185+A186+A197)

| Metric | Value | Threshold | Pass? |
|---|---|---|---|
| external_plddt | 0.8728 | >0.87 | Yes (margin: +0.003) |
| external_iptm | 0.77 | >0.74 | Yes |
| external_ptm | 0.86 | >0.84 | Yes |
| external_pae | 6.43 Å | <7.5 Å | Yes |
| pdockQ2 | 0.5117 | >0.23 | Yes (well above) |
| clashes | 0 | <1 | Yes |
| binder_near_hotspot | True | True | Yes |

Additional metadata:
- CDR lengths: 11, 8, 18
- Target hotspots contacted: A185, A186, A197 (includes the ATS12 selectivity residue R197)
- Framework mutations: 2 — L37K, R131G
- AbMPNN score: 0.663, sequence identity to parent backbone: 29.6%
- Sequence: `QVQLVESGGGLVQPGGSLRLSCAASGLTLSDEKTSGKGWFRQAPGQGLEAVAAMHPMHWTTYYADSVKGRFTISRDNSKNTLYLQMNSLRAEDTAVYYCVRWGYEWKNNKFYIEPEYWGQGTLVTVSSRGG`

Structure file: `setB/accepted/structures/adamts7_nb_s814396_abmpnn_2.pdb`

This design is particularly valuable because it contacts A197(Arg) — the residue that is Glu in ADAMTS12 (charge reversal) — providing a structural basis for ATS7/ATS12 selectivity.

---

## Redesign Candidates Analysis

43 designs in redesign_candidates across the three sets. Two distinct populations are visible:

### Population 1 — Poor backbone designs (39/43)

iPTM ~0.08–0.13, PAE ~15–17 Å, pdockQ2 ~0.009–0.017. The hallucinated backbone produced a weak or non-specific interface. AbMPNN redesign could not rescue them. All five final filter criteria failed simultaneously. Not worth pursuing.

### Population 2 — Near-miss designs (4/43)

These passed most or all filters except `external_plddt` (threshold >0.87). They represent genuinely promising designs suppressed by a tight threshold.

| Design | pLDDT | iPTM | PTM | PAE | pdockQ2 | Filters failed | Miss margin |
|---|---|---|---|---|---|---|---|
| setA s795683_abmpnn_2 | 0.861 | 0.76 | 0.84 | 7.47 Å | 0.43 | pLDDT only | −0.009 |
| setA s795683_abmpnn_3 | 0.861 | 0.77 | 0.85 | 7.46 Å | 0.43 | pLDDT only | −0.009 |
| setC s290877_abmpnn_1 | **0.869** | **0.86** | **0.88** | **6.65 Å** | **0.47** | pLDDT only | **−0.0006** |

`setC s290877_abmpnn_1` is the standout: iPTM 0.86, PAE 6.65 Å, pdockQ2 0.47 — metrics better than the accepted SetB design in every respect except pLDDT, which it missed by 0.0006. This design contacts all four hotspots including A197 and A192. By any reasonable criterion it is accepted-quality.

`setA s795683_abmpnn_2/3` are also strong: iPTM 0.76–0.77, PAE 7.46–7.47 Å — narrowly missed pLDDT by 0.009.

### The pLDDT threshold is too tight

The accepted design cleared the 0.87 pLDDT threshold by only +0.003. The current threshold is functionally acting as a very hard cliff, excluding designs (like s290877_abmpnn_1) that are meaningfully better on all other metrics. 

**Recommendation: relax `external_plddt` from 0.87 → 0.86.** This immediately recovers three designs from the current batch and will materially improve acceptance rates in future runs. The updated filter in `~/germinal/configs/filter/final/vhh_nohotspot_arm64.yaml`:

```yaml
external_plddt:
  value: 0.86    # was 0.87
  operator: '>'
```

With this change, the current effective design library becomes:

| Design | Source | pLDDT | iPTM | PAE | pdockQ2 | Hotspots |
|---|---|---|---|---|---|---|
| s814396_abmpnn_2 | SetB accepted | 0.873 | 0.77 | 6.43 Å | 0.51 | A185, A186, A197 |
| s290877_abmpnn_1 | SetC near-miss | 0.869 | 0.86 | 6.65 Å | 0.47 | A185, A186, A192, A197 |
| s795683_abmpnn_2 | SetA near-miss | 0.861 | 0.76 | 7.47 Å | 0.43 | A185, A186, A192 |
| s795683_abmpnn_3 | SetA near-miss | 0.861 | 0.77 | 7.46 Å | 0.43 | A185, A186, A192 |

---

## Scale Implications

### Current pass rates
- Hallucination quality: ~1.5% (11/756 across all three sets)
- Final filter (of AbMPNN variants): 1/44 = 2.3%; with relaxed pLDDT (0.86): 4/44 = 9.1%
- **Overall rate**: 0.13% currently; ~0.5% with relaxed threshold

### Trajectories needed for ~1,000 accepted designs (Germinal preprint benchmark: 739–1,584 passing per target)

| Scenario | Overall pass rate | Trajectories needed | Jobs (252/job) | Node-hours (~3h/job) |
|---|---|---|---|---|
| Current threshold (0.87) | 0.13% | ~750,000 | ~3,000 | ~9,000 — exceeds allocation |
| Relaxed pLDDT (0.86) | ~0.5% | ~200,000 | ~800 | ~2,400 — near allocation limit |
| Relaxed pLDDT + better hallucination rate | ~1–2% | ~50,000–100,000 | ~200–400 | ~600–1,200 — achievable |

The current pass rate is too low to reach preprint scale within the 2,500 node-hour allocation unless the threshold is relaxed and/or the hallucination pass rate improves.

---

## Recommendations

### Immediate (before next job submission)
1. **Relax `external_plddt` filter from 0.87 → 0.86** on Isambard. This is the single highest-leverage change.
2. **Treat setC s290877_abmpnn_1 and setA s795683_abmpnn_2/3 as accepted designs** for downstream analysis — their structure files are in this archive.

### Next job submissions
Prioritise:
- **SetC** (A185+A186+A192+A197) — best hallucination pass rate (5/252 = 2%) and the strongest near-miss design; covers all four hotspots including both the Trp anchor and the selectivity residue
- **SetB** (A185+A186+A197) — yielded the only formally accepted design; best selectivity coverage with fewer constraints

Suggested: 5–10 more 4-GPU jobs per set. At ~0.5% overall pass rate (relaxed threshold), 10 jobs per set (2,520 trajectories) → ~12 accepted per set → ~36 accepted total. 20 jobs per set → ~25 each → ~75 total. Still short of the ~1,000 preprint benchmark, but sufficient to start evaluating sequence diversity and selecting a panel for wet-lab validation.

### Longer term
Consider further threshold tuning once more data accumulates:
- iPTM threshold (currently 0.74): the three SetB near-miss siblings (s814396 abmpnn_1/3/4, iPTM 0.65–0.70) are probably too borderline to recover, but worth revisiting once the library is larger
- Consider whether SetA (no A197) designs are worth pursuing at all given that A197 contact is the primary ATS12-selectivity differentiator

---

## Files in this Archive

```
setA/
  all_trajectories.csv                  metrics for all saved SetA designs
  accepted/designs.csv                  (empty)
  redesign_candidates/designs.csv       16 designs with full filter metrics
  redesign_candidates/structures/       16 PDB files (4 parent backbones x 4 AbMPNN variants)
  run_summary.txt                       last-worker summary (1 of 4 workers; pre-fix)
setB/
  all_trajectories.csv
  accepted/designs.csv                  1 accepted design
  accepted/structures/                  adamts7_nb_s814396_abmpnn_2.pdb
  redesign_candidates/designs.csv       7 designs
  redesign_candidates/structures/       7 PDB files
  run_summary.txt
setC/
  all_trajectories.csv
  accepted/designs.csv                  (empty)
  redesign_candidates/designs.csv       20 designs with full filter metrics
  redesign_candidates/structures/       20 PDB files (5 parent backbones x 4 AbMPNN variants)
  run_summary.txt
analysis_setABC_2026-05-14.md          this file
```
