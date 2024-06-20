#!/bin/bash

#SBATCH --account=naiss2024-22-540
#SBATCH --ntasks=1                   # nb of *tasks* to be run in // (usually 1), this task can be multithreaded (see cpus-per-task)
#SBATCH --nodes=1                    # nb of nodes to reserve for each task (usually 1)
#SBATCH --cpus-per-task=20            # nb of cpu (in fact cores) to reserve for each task /!\ job killed if commands below use more cores
#SBATCH --mem=96GB                  # amount of RAM to reserve for the tasks /!\ job killed if commands below use more RAM
#SBATCH --time=0-00:30               # maximal wall clock duration (D-HH:MM) /!\ job killed if commands below take more time than reservation
#SBATCH -o ./outputs/blastn_subsamples_%j.%A.%a.out   # standard output (STDOUT) redirected to these files (with Job ID and array ID in file names)
#SBATCH -e ./outputs/blastn_subsamples_%j.%A.%a.err   # standard error  (STDERR) redirected to these files (with Job ID and array ID in file names)
# /!\ Note that the ./outputs/ dir above needs to exist in the dir where script is submitted **prior** to submitting this script
#SBATCH --array=1-100                # 1-N: clone this script in an array of N tasks: $SLURM_ARRAY_TASK_ID will take the value of 1,2,...,N
#SBATCH --job-name=blastn_subsamples        # name of the task as displayed in squeue & sacc, also encouraged as srun optional parameter

#################################################################
# Preparing work (cd to working dir, get hold of input data, convert/un-compress input data when needed etc.)


blast_dir="/proj/applied_bioinformatics/tools/ncbi-blast-2.15.0+-src"
database_dir="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/data/blast_db"
database_name="refseq_viral_genomic"
query_dir="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/data/subset_merged_pairs"
query_names=("subset100.ERR6913121.flash.extendedFrags" "subset1000.ERR6913121.flash.extendedFrags" "subset10000.ERR6913121.flash.extendedFrags")
output_dir="/proj/applied_bioinformatics/users/x_yuqzh/MedBioinfo/analyses/blastn/out_fastq_subsamples_blastn_vs_viral_refseq"

mkdir -p $output_dir

echo START: `date`

# Run BLASTn in parallel for each database
for query_name in "${query_names[@]}"
do
    # srun $blast_dir/blastn -query $query_dir/$query_name.fasta -db $database_dir/$database_name -max_target_seqs 5 -num_threads 1 -evalue 1e-2 -perc_identity 50 -outfmt "6 qacc sacc pident length mismatch gapopen qstart qend sstart send evalue bitscore" -out $output_dir/${query_name}_results.out &
    srun $blast_dir/blastn -query $query_dir/$query_name.fasta -db $database_dir/$database_name -max_target_seqs 5 -num_threads 1 -evalue 10 -perc_identity 10 -out $output_dir/${query_name}_results.out &

wait

echo END: `date`
