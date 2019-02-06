#!/bin/bash

function prepare {
   mkdir -p $scripts/$1
   mkdir -p $scripts/$1/log
   cp templates/$2.template $scripts/$1/$2.sh
	chmod +x $scripts/$1/$2.sh
   sed -i "s|__OUT__|$out|g" "$scripts/$1/$2.sh"
   sed -i "s|__PWD__|$pwd|g" "$scripts/$1/$2.sh"
   sed -i "s|__DIGITS__|$digits|g" "$scripts/$1/$2.sh"
   sed -i "s|__BISMARK_INDEX__|$bismark_index|g" "$scripts/$1/$2.sh"
   sed -i "s|__JUNCTION_INDEX__|$junction_index|g" "$scripts/$1/$2.sh"
   sed -i "s|__CHROM_SIZES__|$chrom_sizes|g" "$scripts/$1/$2.sh"
}

function prepare_all_scripts {
	prepare fastqc fastqc
	prepare trim trim
	prepare alignment alignment
	prepare trim2 trim2
	prepare alignment2 alignment2
	prepare alignment3_junctions alignment3_junctions
	prepare analysis/split3 split3
	prepare analysis/combine combine
	prepare analysis/filter filter
	prepare analysis/merge merge
	prepare bismark bismark
	prepare analysis/pool pool
	prepare bismark-pool bismark-pool
}

pwd=`pwd` # Current directory, do not change

# Remember to set the following variables before running "prepare_all_scripts"
bismark_index="/servers/bio-shares/bioinf-facility/genomes/hg38/BismarkIndex"
junction_index="/servers/frye-bioinf/smb208/Abdul/181023_BSseq/genome/junctions"
chrom_sizes="/servers/frye-bioinf/smb208/Nsun6/180514_BSseq/hub/hg38.chrom.sizes"
out="$pwd/out"
scripts="$pwd/scripts"
digits=3

# Run function to prepare all scripts
prepare_all_scripts

#Step 1: Quality control using FastQC
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/fastqc/fastqc.sh $id
done

#Step 2: Read trimming with Trim galore!
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/trim/trim.sh $id
done

#Step 3: Alignment, step 1
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/alignment/alignment.sh $id
done

#Step 4: Read trimming, step 2
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/trim2/trim2.sh $id
done

#Step 5: Alignment, step 2
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/alignment2/alignment2.sh $id
done

#Step 6: Alignment, step 3
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/alignment3_junctions/alignment3_junctions.sh $id
done

#Step 7: Split3
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/analysis/split3/split3.sh $id
done

#Step 8: Combine bam files
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/analysis/combine/combine.sh $id
done

#Step 9: Filter bam files
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/analysis/filter/filter.sh $id
done

#Step 10: Merge technical replicates
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$((digits-1)) | sort | uniq`
for id in $ids
do
	$scripts/analysis/merge/merge.sh $id
done

#Step 11: Run bismark
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$((digits-1)) | sort | uniq`
for id in $ids
do
	$scripts/bismark/bismark.sh $id
done

#Step 12: Pool biological replicates
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$((digits-2)) | sort | uniq`
for id in $ids
do
	$scripts/analysis/pool/pool.sh $id
done

#Step 13: Bismark on pooled replicates
wait
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$((digits-2)) | sort | uniq`
for id in $ids
do
	$scripts/bismark-pool/bismark-pool.sh $id
done

# Finished!

