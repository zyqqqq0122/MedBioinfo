#!/bin/bash
#SBATCH --job-name=make_krona_pie
#SBATCH --account=naiss2024-22-540
#SBATCH --time=00:20:00
#SBATCH --array=0-9
#SBATCH --cpus-per-task=1
#SBATCH --output=/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/krona/slurm_stdout/krona_%A_%a.out
#SBATCH --error=/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/krona/slurm_stdout/krona_%A_%a.err

KRAKEN2_IMAGE="/proj/applied_bioinformatics/common_data/kraken2.sif"
BRACKEN_REPORT_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/kraken2_bracken/array/bracken"
ACCESSIONS_FILE="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/x_yuqzh_run_accessions.txt"
KRONA_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/krona"
KRAKEN_TOOLS="/proj/applied_bioinformatics/tools/KrakenTools"

SAMPLE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" $ACCESSIONS_FILE)

mkdir -p $KRONA_DIR/krona_fmt
mkdir -p $KRONA_DIR/krona_cleaned
mkdir -p $KRONA_DIR/krona_html

echo START: `date`
echo "Making pie..."

chmod +x -R $KRAKEN_TOOLS/*.py
$KRAKEN_TOOLS/kreport2krona.py -r $BRACKEN_REPORT_DIR/${SAMPLE}.bracken.report -o $KRONA_DIR/krona_fmt/${SAMPLE}.krona

# Remove the taxa prefixes
sed 's/\tk__/\t/g; s/\tp__/\t/g; s/\tc__/\t/g; s/\to__/\t/g; s/\tf__/\t/g; s/\tg__/\t/g; s/\ts__/\t/g' $KRONA_DIR/krona_fmt/${SAMPLE}.krona > $KRONA_DIR/krona_cleaned/${SAMPLE}_cleaned.krona


srun --job-name=krona_${SAMPLE} apptainer exec --bind /proj:/proj $KRAKEN2_IMAGE ktImportText $KRONA_DIR/krona_cleaned/${SAMPLE}_cleaned.krona -o $KRONA_DIR/krona_html/${SAMPLE}.html

echo END: `date`

