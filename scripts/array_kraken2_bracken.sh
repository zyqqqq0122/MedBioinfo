#!/bin/bash
#SBATCH --job-name=single_kraken2_bracken
#SBATCH --account=naiss2024-22-540
#SBATCH --time=1:00:00
#SBATCH --array=0-9
#SBATCH --cpus-per-task=2
#SBATCH --mem=90GB
#SBATCH --output=/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/kraken2_bracken/array/slurm_stdout/kraken2_bracken_%A_%a.out
#SBATCH --error=/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/kraken2_bracken/array/slurm_stdout/kraken2_bracken_%A_%a.err

KRAKEN2_IMAGE="/proj/applied_bioinformatics/common_data/kraken2.sif"
KRAKEN2_DB="/proj/applied_bioinformatics/common_data/kraken_database"
DATA_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/data/sra_fastq"
ACCESSIONS_FILE="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/x_yuqzh_run_accessions.txt"
OUTPUT_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/kraken2_bracken/array/kraken2"
BRACKEN_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/kraken2_bracken/array/bracken"

SAMPLE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" $ACCESSIONS_FILE)
FASTQ_1="$DATA_DIR/${SAMPLE}_1.fastq.gz"
FASTQ_2="$DATA_DIR/${SAMPLE}_2.fastq.gz"

mkdir -p $OUTPUT_DIR
mkdir -p $BRACKEN_DIR

echo START: `date`

# Run Kraken2
echo "Run Kraken2..."
srun --job-name=kraken2_${SAMPLE} apptainer exec --bind /proj:/proj $KRAKEN2_IMAGE kraken2 --db $KRAKEN2_DB --threads 2 --paired --gzip-compressed --output $OUTPUT_DIR/${SAMPLE}.kraken2.out --report $OUTPUT_DIR/${SAMPLE}.kraken2.report $FASTQ_1 $FASTQ_2

# Run Bracken
echo "Run Bracken..."
srun --job-name=bracken_${SAMPLE} apptainer exec --bind /proj:/proj $KRAKEN2_IMAGE bracken -d $KRAKEN2_DB -i $OUTPUT_DIR/${SAMPLE}.kraken2.report -o $BRACKEN_DIR/${SAMPLE}.bracken.out -w $BRACKEN_DIR/${SAMPLE}.bracken.report -r 150

echo END: `date`

