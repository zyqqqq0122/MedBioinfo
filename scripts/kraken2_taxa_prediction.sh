#!/bin/bash
#SBATCH --job-name=kraken2_taxa_prediction
#SBATCH --account=naiss2024-22-540
#SBATCH --time=1:00:00
#SBATCH --mem=90GB
#SBATCH --output=/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/kraken2/slurm_stdout/kraken2_%A_%a.out
#SBATCH --error=/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/kraken2/slurm_stdout/kraken2_%A_%a.err

USERNAME="x_yuqzh"
KRAKEN2_IMAGE="/proj/applied_bioinformatics/common_data/kraken2.sif"
KRAKEN2_DB="/proj/applied_bioinformatics/common_data/kraken_database"
DATA_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/data/sra_fastq"
FASTQ_1="$DATA_DIR/ERR6913303_1.fastq.gz"
FASTQ_2="$DATA_DIR/ERR6913303_2.fastq.gz"
OUTPUT_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/kraken2/kraken2_results"

mkdir -p $OUTPUT_DIR

echo START: `date`
# Run Kraken2
srun apptainer exec --bind /proj:/proj $KRAKEN2_IMAGE kraken2 -db $KRAKEN2_DB --threads 1 --paired --gzip-compressed --output $OUTPUT_DIR/ERR6913303.kraken2.out --report $OUTPUT_DIR/ERR6913303.kraken2.report $FASTQ_1 $FASTQ_2

echo END: `date`

