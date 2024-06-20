#!/bin/bash
#SBATCH --job-name=blastn_array
#SBATCH --account=naiss2024-22-540
#SBATCH --cpus-per-task=12
#SBATCH --time=00:40:00
#SBATCH --array=0-9
#SBATCH --output=blastn_array_%A_%a.out
#SBATCH --error=blastn_array_%A_%a.err

BLAST_DIR="/proj/applied_bioinformatics/tools/ncbi-blast-2.15.0+-src"
SINGULARITY_IMAGE="/proj/applied_bioinformatics/common_data/meta.sif"

USERNAME="x_yuqzh"
BLAST_DB_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/data/blast_db"
DATA_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/data/merged_pairs"
FASTA_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/data/merged_pairs_fasta"
ANALYSES_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses"
ACCESSIONS_FILE="${ANALYSES_DIR}/${USERNAME}_run_accessions.txt"
OUTPUT_DIR="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/blastn/blastn_results_full"

mkdir -p $FASTA_DIR
mkdir -p $OUTPUT_DIR

echo START: `date`

# Get the specific accession number for this task
ACCESSION=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" $ACCESSIONS_FILE)

# Convert FASTQ to FASTA
apptainer exec $SINGULARITY_IMAGE seqkit fq2fa $DATA_DIR/${ACCESSION}.flash.extendedFrags.fastq.gz -o $FASTA_DIR/${ACCESSION}.flash.extendedFrags.fasta

# Run BLASTn with the sample AccNum as the job name
srun --account=naiss2024-22-540 --cpus-per-task=12 --time=00:40:00 --job-name=${ACCESSION} $BLAST_DIR/blastn -query $FASTA_DIR/${ACCESSION}.flash.extendedFrags.fasta -db $BLAST_DB_DIR/refseq_viral_genomic -max_target_seqs 5 -num_threads 12 -evalue 1e-3 -outfmt 6 -out $OUTPUT_DIR/${ACCESSION}_results.out

# Compress the FASTA file to save space
gzip $FASTA_DIR/${ACCESSION}.flash.extendedFrags.fasta

echo END: `date`
