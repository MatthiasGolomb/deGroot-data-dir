#!/bin/bash
#SBATCH --job-name=adamts7_setB
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=0
#SBATCH --partition=workq
#SBATCH --gpus=4
#SBATCH --output=jobs/%x-%j.out
#SBATCH --error=jobs/%x-%j.err

set -euo pipefail

GERMINAL_SIF=/projects/u6jt/containers/germinal-arm64.sif
AF2_PARAMS=/projects/u6jt/germinal_params
AF3_PARAMS=/projects/u6jt/af3_params
AF3_DB=/projects/u6jt/af3_databases
AF3_SANDBOX=/scratch/u6jt/legame.u6jt/af3_sandbox
WORKDIR=$PWD

for f in "$GERMINAL_SIF" "$AF3_SANDBOX" "$AF2_PARAMS" "$AF3_PARAMS" "$AF3_DB" "$WORKDIR/pdbs/adamts7.pdb"; do
    [[ -e "$f" ]] || { echo "ERROR: missing $f"; exit 1; }
done
mkdir -p "$WORKDIR/jobs" "$WORKDIR/results"

echo "=============================="
echo "Job:        $SLURM_JOB_ID"
echo "Node:       $SLURM_NODELIST"
echo "Set:        B — hotspots A185,A186,A197"
echo "Started:    $(date)"
echo "=============================="

run_worker() {
    local GPU_ID=$1
    local LOG="$WORKDIR/jobs/${SLURM_JOB_NAME}-${SLURM_JOB_ID}-gpu${GPU_ID}.log"
    echo "Starting worker on GPU ${GPU_ID}" | tee -a "$LOG"

    apptainer exec         --nv         --writable-tmpfs         --env CUDA_VISIBLE_DEVICES=${GPU_ID}         --bind /usr/lib/apptainer:/usr/lib/apptainer         --bind /etc/apptainer:/etc/apptainer         --bind /var/lib/apptainer:/var/lib/apptainer         --bind "${AF3_SANDBOX}:/workspace/af3_sandbox"         --bind "${AF2_PARAMS}:/workspace/params"         --bind "${AF3_PARAMS}:/workspace/af3_params"         --bind "${AF3_DB}:/workspace/af3_databases"         --bind "${WORKDIR}/configs:/workspace/configs"         --bind "${WORKDIR}/pdbs:/workspace/pdbs"         --bind "${WORKDIR}/results:/workspace/results"         "${GERMINAL_SIF}"         python run_germinal.py             run=vhh             target=adamts7_setB             "filter/initial=vhh_nohotspot_arm64"             "filter/final=vhh_nohotspot_arm64"             structure_model=af3             af3_sif_path="/workspace/af3_sandbox"             af3_model_dir=/workspace/af3_params             af3_db_dir=/workspace/af3_databases             af_params_dir=/workspace/params             experiment_name=adamts7_setB_v1             max_trajectories=63             dssp_path=/usr/bin/mkdssp             ${EXTRA_ARGS:-}         >> "$LOG" 2>&1
}

# Launch all 4 workers in parallel
PIDS=()
for GPU_ID in 0 1 2 3; do
    run_worker $GPU_ID &
    PIDS+=($!)
done

# Wait and check exit codes
FAILED=0
for PID in "${PIDS[@]}"; do
    wait $PID || FAILED=$((FAILED + 1))
done

echo "=============================="
echo "Finished:   $(date)"
[[ $FAILED -gt 0 ]] && echo "WARNING: $FAILED worker(s) exited non-zero" || echo "All workers completed successfully"
echo "=============================="

[[ $FAILED -gt 0 ]] && exit 1 || exit 0
