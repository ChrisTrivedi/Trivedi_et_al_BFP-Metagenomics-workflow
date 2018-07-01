#!/bin/bash

### Description ###
# This is not an executable script, rather a workflow, including the scripts I used to process raw metagenomic reads.

# The majority of these programs were run on an HPC which used Slurm as the job organizer. There are a few instances where it was easier to run a given command on my local computer - I will point these out.

# The output of this workflow was geared to then be input into Anvi'o for visualization and further processing, however, those script will not be covered here. The Anvi'o website has a great tutorial that covers this process.

# Keep in mind that up to the point of assembling reads (Megahit), each process must be done on individual sample files.

### Software Used ###
# Megahit
# Bowtie 2
# BFC
# BBMap
# FastQC
# SAMtools
# PEAR

### Quality Control ###

# Run BBDuk (part of BBMap) on raw reads to remove sequening adapters
bbduk.sh in1=Data/R1.fastq.gz in2=Data/R2.fastq.gz out1=BBDukOut/R1_adapt.fq out2=BBDukOut/R2_adapt.fq ref=bbmap/resources/adapters.fa ktrim=r k=23 mink=11 hdist=1 tpe

# Use PEAR to pair end reads for use when aligning
pear -y 16G -j 4 -c 40 -n 150 -m 300 -p 0.001 -f BBDukOut/R1_adapt.fq -r BBDukOut/R2_adapt.fq -o Joined/<sample_name>

# Use FastQC to check the quality of sequencing reads
FastQC/fastqc BBDukOut/R1_adapt.fq BBDukOut/R2_adapt.fq -outdir /QC --threads 16

# Next we use a tool called BBRepair (part of BBMap) which helps to reorient paired-end files that have become disordered.
bbmap/repair.sh in=BBDukOut/R1_adapt.fq in2=BBDukOut/R2_adapt.fq out=Repair/R1_repair.fq  out2=Repair/R2_repair.fq outs=Repair/singles.fastq 

# BFC is used to error correct Illumina sequnces, where forward reads are used to correct reverse reads and vice versa.
# R2 correction
bfc -1 -s 5.3 -k 21 -t 4 Repair/R1_repair.fq Repair/R2_repair.fq > BFC/R2_bfc.fq

# R1 correction
bfc -1 -s 5.3 -k 21 -t 4 Repair/R2_repair.fq Repair/R1_repair.fq > BFC/R1_bfc.fq

# I then ran FastQC again and BBRepair to make sure nothing went awry during error correction.
# FastQC 2
FastQC/fastqc BFC/R1_bfc.fq BFC/R2_bfc.fq -outdir QC --threads 48

# BBRepair 2
bbmap/repair.sh in=BFC/R1_bfc.fq in2=BFC/R2_bfc.fq out=Repair2/R1_repair_2.fq  out2=Repair2/R2_repair_2.fq outs=Repair2/singles_2.fastq

### Assembly ###

# There are two assemblies I ran - one for each individual sample, and one as a co-assembly of all samples for a given environment. 

# Note: This is where the Joined files come in - they can aide Megahit in the assembly process

# Single assembly
megahit/megahit --min-contig-len 1000 --tmp-dir ASSEMBLY/tmp/ -r Joined/<sample_name>.assembled.fastq -1 Repair2/BR1_repair_2.fq -2 Repair2/R2_repair_2.fq -o /ASSEMBLY/<sample_name>/ -t 16 -m 68719476736

# Co-Assembly - I define environment variables to make calling the individual R1 and R2 files easier.
# Define Environment variables
R1s=`ls Repair2/*<universial identifier in all samples>*R1_repair_2* | python -c 'import sys; print ",".join([x.strip() for x in sys.stdin.readlines()])'`

R2s=`ls Repair2/*<universial identifier in all samples>*R2_repair_2* | python -c 'import sys; print ",".join([x.strip() for x in sys.stdin.readlines()])'`

Joins=`ls Joined/*<universial identifier in all samples>*.assembled* | python -c 'import sys; print ",".join([x.strip() for x in sys.stdin.readlines()])'`

# Run Megahit
/projects/chtr8204/Software/megahit/megahit --min-contig-len 1000 --tmp-dir ASSEMBLY/tmp/ -r $Joins -1 $R1s -2 $R2s -o ASSEMBLY/Co_Assembly -t 24 -m 135291469824

# At this point you will have assembled contig files. You can move on to alignment or you can format those files for input into Anvi'o down the line. This is what I did (and what is suggested in the Anvi'o Metagenomics workflow)













