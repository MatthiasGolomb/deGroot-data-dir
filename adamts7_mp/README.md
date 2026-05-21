# Germinal Pipeline — Input/Output Example for ADAMTS7 SetB
*Prepared for Matthias Golomb, UCL Unified AI Kubeflow platform*

---

## Biological context (brief)

**Target protein:** ADAMTS7 — a human metalloprotease enzyme involved in vascular disease. We are trying to design inhibitory binders against it.

**Binder format:** VHH nanobody (single-domain antibody fragment, ~130 amino acids). Much smaller than a conventional antibody, which makes computational design tractable.

**Goal:** Design a VHH that binds specifically to the active-site region of ADAMTS7 at three chosen "hotspot" residues — positions 185 (Tyr), 186 (Asp), 197 (Arg) on chain A — while avoiding cross-reactivity with the closely related protease ADAMTS12 (residue 197 is Arg in ADAMTS7 but Glu in ADAMTS12, so a binder contacting it gains selectivity).

---

## What the Germinal pipeline does

[Germinal](https://github.com/sokrypton/ColabDesign) is an AI-driven antibody design pipeline. Each trajectory runs three steps in series:

1. **Hallucination** (RFdiffusion/ColabDesign) — generates a novel VHH backbone de novo, biased to place CDR loops near the specified hotspot residues. ~97% of trajectories are rejected here if the model cannot find a confident low-loss solution with the hotspot constraint satisfied.
2. **Sequence design** (AbMPNN) — given an accepted backbone, designs 4 amino acid sequences that are predicted to fold into that backbone. Produces 4 sequence variants per backbone.
3. **Structural validation** (AlphaFold3 cofold) — independently predicts the 3D structure of the binder + target complex. Metrics from this prediction are used to filter designs.

This run: **4 GPU workers × 63 trajectories = 252 trajectories total**. 2 backbones passed hallucination (0.8%), yielding 8 AbMPNN sequence variants, of which **1 passed all final filters**.

---

## Files in this package

### Inputs

| File | Description |
|---|---|
| `inputs/adamts7_mp.pdb` | Target structure — ADAMTS7 metalloprotease domain only, 225 residues, chain A. AF3-predicted structure. This is what the pipeline designs binders against. |
| `inputs/configs/target/adamts7_setB.yaml` | Target configuration: name, PDB path (as used on Isambard), chain assignment, hotspot residues. |
| `inputs/configs/filter/initial/vhh_nohotspot_arm64.yaml` | Initial filter applied after hallucination: clash check only (no steric clashes between binder and target). |
| `inputs/configs/filter/final/vhh_nohotspot_arm64.yaml` | Final filter applied after AF3 cofold. Six criteria — see below. |
| `inputs/run_adamts7_setB.sbatch` | Slurm batch script used to run this job on Isambard-AI (NVIDIA GH200, ARM64). Shows the exact `python run_germinal.py` command and all arguments. The Kubeflow equivalent would replace the `apptainer exec` wrapper with a container job. |

**Note on paths in `adamts7_setB.yaml`:** The `target_pdb_path` field reads `pdbs/adamts7.pdb` — that is the path *relative to the Germinal working directory on Isambard*. The actual file is `inputs/adamts7_mp.pdb` in this zip.

#### Final filter thresholds

These are all computed from the AlphaFold3 co-folding prediction of [binder + target]:

| Metric | Threshold | What it measures |
|---|---|---|
| `external_plddt` | > 0.86 | AF3 per-residue confidence averaged over the binder (0–1; analogous to R² — higher = more confident fold) |
| `external_iptm` | > 0.74 | AF3 interface predicted TM-score; confidence in the relative orientation of binder and target (0–1) |
| `external_ptm` | > 0.84 | AF3 predicted TM-score for the whole complex |
| `external_pae` | < 7.5 Å | Mean predicted aligned error across the complex (Å); lower = more confident inter-chain geometry |
| `pdockq2` | > 0.23 | Interface quality score derived from AF2-Multimer; > 0.23 indicates a likely true interface |
| `clashes` | < 1 | Number of steric clashes in the unrelaxed structure |

---

### Outputs

| File | Description |
|---|---|
| `outputs/adamts7_nb_s814396_abmpnn_2.pdb` | The accepted design. A PDB file containing both the binder (chain B, ~130aa VHH) and the target (chain A, 225aa ADAMTS7 MP domain) as co-folded by AlphaFold3. Open in PyMOL or ChimeraX. |
| `outputs/designs.csv` | Full metrics for this design: all six filter values (and many more), the designed sequence, CDR lengths, hotspot contacts, framework mutations, and timing. |
| `outputs/analysis_setABC_2026-05-14.md` | Analysis document for this batch — run overview, pass rates, why the threshold was set where it was, and commentary on near-miss designs. |

#### Accepted design summary

- **Name:** `adamts7_nb_s814396_abmpnn_2`
- **Sequence (133aa):** `QVQLVESGGGLVQPGGSLRLSCAASGLTLSDEKTSGKGWFRQAPGQGLEAVAAMHPMHWTTYYADSVKGRFTISRDNSKNTLYLQMNSLRAEDTAVYYCVRWGYEWKNNKFYIEPEYWGQGTLVTVSSRGG`
- **CDR lengths:** 11, 8, 18 (CDR1, CDR2, CDR3)
- **Hotspots contacted:** A185, A186, A197 ✓
- **AF3 pLDDT:** 0.873 | **iPTM:** 0.77 | **PAE:** 6.4 Å | **pdockQ2:** 0.51
- **Framework mutations from template:** 2 (L37K, R131G)
- **Design time per trajectory:** ~15 minutes on 1× GH200 GPU

---

## Pipeline code

Germinal ARM64 branch (used here): https://github.com/rensdg-code/germinal (branch: `arm64`)

The container used on Isambard: `ghcr.io/rensdg-code/germinal:latest-arm64`

The key entry point is `run_germinal.py` with Hydra config composition — `run=vhh`, `target=adamts7_setB`, `filter/initial=...`, `filter/final=...`. All arguments visible in the sbatch script.
