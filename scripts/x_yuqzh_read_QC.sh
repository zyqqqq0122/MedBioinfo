#!/bin/bash

date

USERNAME="x_yuqzh"
DB_PATH="/proj/applied_bioinformatics/common_data/sample_collab.db"
ANALYSES_DIR="./analyses"
DATA_DIR="./data/sra_fastq"
MERGED_DIR="./data/merged_pairs"
SCRIPTS_DIR="./scripts"
RUN_ACCESSIONS_FILE="${ANALYSES_DIR}/${USERNAME}_run_accessions.txt"
SINGULARITY_IMAGE="/proj/applied_bioinformatics/common_data/meta.sif"

mkdir -p $DATA_DIR
mkdir -p $MERGED_DIR

# Export the list of sequencing run identifiers
echo "Exporting run accessions..."
sqlite3 -batch $DB_PATH "select run_accession from sample_annot spl left join sample2bioinformatician s2b using(patient_code) where username='$USERNAME';" -noheader -csv > $RUN_ACCESSIONS_FILE

# Download FASTQ files using fastq-dump
echo "Downloading FASTQ files..."
cat $RUN_ACCESSIONS_FILE | srun --account naiss2024-22-540 --cpus-per-task=16 --time=00:30:00 apptainer exec $SINGULARITY_IMAGE xargs fastq-dump --split-files --gzip --defline-seq '@$ac.$si.$ri' -O $DATA_DIR

# Verify the number of FASTQ files
echo "Verifying number of FASTQ files..."
NUM_ACCESSIONS=$(wc -l < $RUN_ACCESSIONS_FILE)
NUM_FASTQ_FILES=$(ls $DATA_DIR/*.fastq.gz | wc -l)
EXPECTED_NUM_FILES=$((NUM_ACCESSIONS * 2))

if [ $NUM_FASTQ_FILES -ne $EXPECTED_NUM_FILES ]; then
  echo "Error: Number of FASTQ files ($NUM_FASTQ_FILES) does not match expected number ($EXPECTED_NUM_FILES)."
else
  echo "Number of FASTQ files is correct: $NUM_FASTQ_FILES."
fi

# Count the number of reads in each FASTQ file
echo "Counting the number of reads in each FASTQ file..."
for file in $DATA_DIR/*.fastq.gz; do
  NUM_READS=$(zcat $file | echo $((`wc -l` / 4)))
  echo "$file: $NUM_READS reads"
done

# Check base call quality scores encoding
# echo "Checking base call quality scores encoding for a sample file..."
# SAMPLE_FILE=$(ls $DATA_DIR/*.fastq.gz | head -n 1)
# zcat $SAMPLE_FILE | head -n 4
echo "The base call quality scores are encoded in these FASTQ files using ASCII characters to represent Phred quality scores. The ASCII value of the character can be converted to the Phred score by subtracting a fixed value (33)."

# Print statistics for each FASTQ file using seqkit
echo "Printing statistics for each FASTQ file obtained from seqkit stats..."
srun --account naiss2024-22-540 --cpus-per-task=8 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE seqkit stats --threads 8 $DATA_DIR/*.fastq.gz

# Check for duplicate reads in FASTQ files using seqkit
echo "Checking for duplicate reads in FASTQ files..."
ls $DATA_DIR/*.fastq.gz | xargs -I{} -n 1 sh -c 'BASENAME=$(basename {} .fastq.gz); zcat {} | srun --account naiss2024-22-540 --cpus-per-task=8 --time=00:10:00 apptainer exec '"$SINGULARITY_IMAGE"' seqkit rmdup -s --threads 8 -o '"$DATA_DIR"'/cleaned_sra_fastq/${BASENAME}_cleaned.fastq.gz'
echo "The FASTQ files have not been de-replicated. Considering we will ultimately want to produce quantitative estimates of the pathogens present in the patient samples, the replicated version of files is better to work with."

# Check if FASTQ files have been trimmed of adapters using seqkit
echo "Checking if FASTQ files have been trimmed of adapters AGATCGGAAGAGCACACGTCTGAACTCCAGTCA and AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT..."
ADAPTER_SEQ1="AGATCGGAAGAGCACACGTCTGAACTCCAGTCA"
srun --account naiss2024-22-540 --cpus-per-task=8 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE seqkit locate -p $ADAPTER_SEQ1 --threads 8 $DATA_DIR/*.fastq.gz
ADAPTER_SEQ2="AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT"
srun --account naiss2024-22-540 --cpus-per-task=8 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE seqkit locate -p $ADAPTER_SEQ2 --threads 8 $DATA_DIR/*.fastq.gz
echo "The FASTQ files have already been trimmed of their sequencing kit adapters."

# Try with shortened adapter sequences
# echo "Checking if FASTQ files have been trimmed of adapters AGATCGGAAGAGCACACGTCTGAACTCCAGTCA and AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT..."
# ADAPTER_SEQ1="AGATCGGAAGAGCACACGTCTGAACTCC"
# srun --cpus-per-task=4 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE seqkit locate -p $ADAPTER_SEQ1 --threads 4 $DATA_DIR/*.fastq.gz
# ADAPTER_SEQ2="AGATCGGAAGAGCGTCGTGTAGGGAAAG"
# srun --cpus-per-task=4 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE seqkit locate -p $ADAPTER_SEQ2 --threads 4 $DATA_DIR/*.fastq.gz

# Quality control the raw sequencing FASTQ files with fastQC
echo "Performing quality control with fastQC..."
mkdir -p ${ANALYSES_DIR}/fastqc
srun --account naiss2024-22-540 --cpus-per-task=8 --time=00:30:00 apptainer exec $SINGULARITY_IMAGE xargs -I{} -a $RUN_ACCESSIONS_FILE fastqc --threads 8 -o ${ANALYSES_DIR}/fastqc $DATA_DIR/{}_1.fastq.gz $DATA_DIR/{}_2.fastq.gz
echo "From the fastQC output files, it can be concluded that reads have been trimmed to exclude bases with low quality scores and sequencing library adapters."

# Merge paired-end reads using flash
echo "Merging paired-end reads with flash..."
srun --account naiss2024-22-540 --cpus-per-task=8 --time=00:30:00 apptainer exec $SINGULARITY_IMAGE xargs -a $RUN_ACCESSIONS_FILE -I{} flash $DATA_DIR/{}_1.fastq.gz $DATA_DIR/{}_2.fastq.gz --threads=8 --output-directory=$MERGED_DIR --output-prefix={}.flash 2>&1 | tee -a ${ANALYSES_DIR}/${USERNAME}_flash.log
# srun --account naiss2024-22-540 --cpus-per-task=1 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE seqkit stat ${DATA_DIR}/*.fastq.gz
# srun --account naiss2024-22-540 --cpus-per-task=1 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE seqkit stat ${MERGED_DIR}/*.extendedFrags.fastq
echo "The proportion of the reads were merged successfully is indicated by the Percent combined in the output of flash. The .histogram file suggests the frequency of the DNA library insert sizes. The total number of base pairs in the merged reads is close to the initial unmerged reads, it suggests that the merging process only removed redundant information."

# Download reference genomes
echo "Downloading PhiX reference genome..."
mkdir -p ./data/reference_seqs
srun --account naiss2024-22-540 --cpus-per-task=1 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE efetch -db nuccore -id NC_001422 -format fasta > ./data/reference_seqs/PhiX_NC_001422.fna
echo "Downloading SARS-CoV-2 reference genome..."
srun --account naiss2024-22-540 --cpus-per-task=1 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE efetch -db nuccore -id NC_045512 -format fasta > ./data/reference_seqs/SC2_NC_045512.fna
echo "Downloading Corynebacterium accolens reference genome (https://www.ncbi.nlm.nih.gov/datasets/genome/GCF_023520795.1/)..."
srun --account naiss2024-22-540 --cpus-per-task=1 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE efetch -db nuccore -id NZ_CP046605 -format fasta > ./data/reference_seqs/CoryAcc_NZ_CP046605.fna

# Create bowtie2 index for reference genomes
echo "Creating bowtie2 index for PhiX genome..."
mkdir -p ./data/bowtie2_DBs
srun --account naiss2024-22-540 --cpus-per-task=1 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE bowtie2-build -f ./data/reference_seqs/PhiX_NC_001422.fna ./data/bowtie2_DBs/PhiX_bowtie2_DB
echo "Creating bowtie2 index for SARS-CoV-2 genome..."
srun --account naiss2024-22-540 --cpus-per-task=1 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE bowtie2-build -f ./data/reference_seqs/SC2_NC_045512.fna ./data/bowtie2_DBs/SC2_bowtie2_DB
echo "Creating bowtie2 index for Corynebacterium accolens genome..."
srun --account naiss2024-22-540 --cpus-per-task=1 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE bowtie2-build -f ./data/reference_seqs/CoryAcc_NZ_CP046605.fna ./data/bowtie2_DBs/CoryAcc_bowtie2_DB


# Align merged reads against reference genomes
echo "Aligning merged reads against PhiX genome..."
mkdir -p ${ANALYSES_DIR}/bowtie
srun --account naiss2024-22-540 --cpus-per-task=8 --time=00:30:00 apptainer exec $SINGULARITY_IMAGE bowtie2 -x ./data/bowtie2_DBs/PhiX_bowtie2_DB -U $MERGED_DIR/ERR*.extendedFrags.fastq -S ${ANALYSES_DIR}/bowtie/${USERNAME}_merged2PhiX.sam --threads 8 --no-unal 2>&1 | tee ${ANALYSES_DIR}/bowtie/${USERNAME}_bowtie2_PhiX.log
echo "No hits against PhiX were observed."
echo "Aligning merged reads against SARS-CoV-2 genome..."
srun --account naiss2024-22-540 --cpus-per-task=8 --time=00:30:00 apptainer exec $SINGULARITY_IMAGE bowtie2 -x ./data/bowtie2_DBs/SC2_bowtie2_DB -U $MERGED_DIR/ERR*.extendedFrags.fastq -S ${ANALYSES_DIR}/bowtie/${USERNAME}_merged2SC2.sam --threads 8 --no-unal 2>&1 | tee ${ANALYSES_DIR}/bowtie/${USERNAME}_bowtie2_SC2.log
echo "SARS-CoV-2: 0.18% overall alignment rate."
echo "Aligning merged reads against Corynebacterium accolens genome..."
srun --account naiss2024-22-540 --cpus-per-task=8 --time=00:30:00 apptainer exec $SINGULARITY_IMAGE bowtie2 -x ./data/bowtie2_DBs/CoryAcc_bowtie2_DB -U $MERGED_DIR/ERR*.extendedFrags.fastq -S ${ANALYSES_DIR}/bowtie/${USERNAME}_merged2CoryAcc.sam --threads 8 --no-unal 2>&1 | tee ${ANALYSES_DIR}/bowtie/${USERNAME}_bowtie2_CoryAcc.log
echo "Corynebacterium accolens: 0.60% overall alignment rate."

# Combine quality control results into one unique report using MultiQC
echo "Combining quality control results with MultiQC..."
srun --account naiss2024-22-540 --cpus-per-task=1 --time=00:10:00 apptainer exec $SINGULARITY_IMAGE multiqc --force --title "${USERNAME} sample sub-set" ${MERGED_DIR} ${ANALYSES_DIR}/fastqc/ ${ANALYSES_DIR}/${USERNAME}_flash.log ${ANALYSES_DIR}/bowtie/

date

