# Analysis of transcriptomic BS-seq data

Here we describe the analysis of transcriptomic BS-seq data. This approach was used in Sajini *et al.* (2019).

## Getting Started

These instructions will describe how to analyse transcriptomic BS-seq data. You will need access to a computer cluster or similar to run some of the following steps.

### Prerequisites

This pipeline uses many external tools and will only run on a UNIX-like environment.

Required software:

* Awk (v4.0.1)
* Bismark (v0.14.4)
* FastQC (v0.11.3)
* bamutils from the NGSUtils suite (v0.5.9)
* SAMtools (v0.1.19-96b5f2294a)
* seqtk (v1.2-r102-dirty)
* Trim galore! (v.0.4.0)

Please make sure that these are available and found in the current `$PATH` (or edit the template scripts to include the full path). The versions listed are the ones we used, but the pipeline will probably work with other versions.

### Installation

Download the latest version ([v1.0](https://github.com/susbo/trans-bsseq/releases)) from the releases tab.

The following commands will unpack the pipeline in your current directory:

````bash
tar xvfc trans-bsseq-1.0.tar.gz
cd trans-bsseq-1.0
````

#### Preparing the Bismark junction index
The following instructions can be used to create a splice juction genome and to index it for use with Bismark.
````bash
ngsutils="/path/to/ngsutils/bin"

mkdir genome
cd genome
wget ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_28/gencode.v28.annotation.gtf.gz
mkdir junctions
$ngsutils/gtfutils junctions -known gencode.v28.annotation.gtf.gz genome.fa > junctions/junctions.fa
bismark_genome_preparation --bowtie1 junctions
````
This will create a splice junction index at `genome/junctions`.

#### Running the analysis on the demo data

Go to the `demo` directory using `cd demo`. The example data is already located in the `demo/data` directory and contains two biological replicates with two technical replicates each: `Diff.[12].[78].fq.gz`. Only reads that mapped to chr1:1-3,000,000 are included in the example fastq files. A copy of the template files is also available in the `demo/templates` folder.

Edit the `pipeline.sh` script to set the environmental variables (see the section on setting the environmental variables below) and then run `pipeline.sh`. If all the required software is available, the example data should be analyzed in about ~20 minutes using 24 cores.

## Running the analysis
The analysis assumes that you are running the analysis from the `$pwd` directory. Your scripts will be written to the `$scripts` directory and your output will be saved to the `$out` directory.

### Setting environmental variables before preparing the scripts
Before preparing the scripts, please ensure that you have set the following environmental variables:

* `$pwd` - Absolute path to the current directory. This directory must contain the `data` and `template` folders.
* `$out` - Absolute path to output directory. All results will be saved here.
* `$scripts` - Absolute path to script directory. All scripts will be stored here.
* `$digits` - Number of fields in each file name (does not count the ".fq.gz" part).
* `$bismark_index` - Absolute path to the Bismark index, this is a standard Bismark index for the *hg38* genome.
* `$junction_index` - Absolute path to Bismark junction index, created according to the instructions above.
* `$chrom_sizes` - Absolute path to a [hg38.chrom_sizes](http://hgdownload.cse.ucsc.edu/goldenpath/hg38/bigZips/hg38.chrom.sizes) file.

### Preparing the raw data files
Firstly, create a `data` directory and put the samples there after giving them meaningful names. In this example, we have files named:
`Undiff.[1-5].[78].fq.gz` and `Diff.[1-5].[78].fq.gz`.

The sample names must have at least three fields separateby by a dot ".", the first is the group/treatment (Undiff or Diff), the second the biological replicate (1-5) and the third is the technical replicate (7-8). The number of fields must be saved in the `$digits` variable, any additonal fields must be put into the beginning of the file names (e.g., `Lots-of.Extra-info.Diff.1.7.fq.gz`) and will be ignored.

### Preparing each script from a template
Each step in the pipeline has a separate template file with the neccessary commands. In order to run the script, you need to create folder (typically named after the script) and copy the script to that folder and add the correct environmental variables to that script before running it.

The following bash function can be used to copy and rename each template file:

````bash
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
````

The first argument is the target folder and the second is the template file name. The steps below assume that each template has been prepared according to the following instructions:

````bash
# Prepare each template
# Please remember to set all environmental variables before running it.
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
````

### Running the scripts

All examples below assume that a sample is named according to the `Name.Repl.Tech.fq.gz` structure. The steps below are also found in the `demo/pipeline.sh` file.

#### Step 1: Quality control using FastQC
````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/fastqc/fastqc.sh $id
done
````
This will produce a FastQC report for each raw file.

Input file:

* `$scripts/data/Name.Repl.Tech.fq.gz`

Output file: 

* `$out/fastqc/Name.Repl.Tech.fq_fastqc.html`

#### Step 2: Read trimming with Trim galore!

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/trim/trim.sh $id
done
````

This will remove sequencing adapters and exclude reads with length <20.

Input file:

* `$scripts/data/Name.Repl.Tech.fq.gz`

Output file: 

* `$out/trim/Name.Repl.Tech_trimmed.fq.gz`

#### Step 3: Alignment, step 1

Must wait for **Step 2** to finish for the relevant $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/alignment/alignment.sh $id
done
````
This will align the trimmed reads to the reference genome and also save the unmapped and ambiguous reads.

Input file:

* `$out/trim/Name.Repl.Tech_trimmed.fq.gz`

Output files: 

* `$out/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_ bismark.bam`
* `$out/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_unmapped_reads.fq.gz`
* `$out/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_ambiguous_reads.fq.gz`

#### Step 4: Read trimming, step 2

Must wait for **Step 3** to finish for the relevant $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/trim2/trim2.sh $id
done
````
This will remove the three last nucleotides from the unmapped and ambiguous reads.

Input files:

* `$out/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_unmapped_reads.fq.gz`
* `$out/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_ambiguous_reads.fq.gz`

Output files: 

* `$out/trim2/unmapped/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz`
* `$out/trim2/ambiguous/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz`

#### Step 5: Alignment, step 2

Must wait for **Step 4** to finish for the relevant $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/alignment2/alignment2.sh $id
done
````
This will attempt to align the previously unaligned and ambiguous reads.

Input files:

* `$out/trim2/unmapped/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz`
* `$out/trim2/ambiguous/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz`

Output files: 

* `$out/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_bismark.bam`
* `$out/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_ambiguous_reads.fq.gz`
* `$out/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_unmapped_reads.fq.gz`
* `$out/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz_bismark.bam`
* `$out/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz_ambiguous_reads.fq.gz`
* `$out/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz_unmapped_reads.fq.gz`

#### Step 6: Alignment, step 3

Must wait for **Step 5** to finish for the relevant $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/alignment3_junctions/alignment3_junctions.sh $id
done
````

This will attempt to align the previously twice unaligned reads to splice junctions.

Input file:

* `$out/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_unmapped_reads.fq.gz`

Output file: 

* `$out/alignment3_junctions/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.un.fq.gz_bismark.bam`

#### Step 7: Split3

Must wait for **Step 6** to finish for the relevant $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/analysis/split3/split3.sh $id
done
````

This step will remap the splice junction alignments to genomic coordinates and replace N in the CIGAR string with D for compatibility with the *bismark_methylation_extractor*.

Input file:

* `$out/alignment3_junctions/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.un.fq.gz_bismark.bam`

Output file: 

* `$out/alignment3_junctions/splitNtoD/Name.Repl.Tech.bam`

#### Step 8: Combine bam files

Must wait for **Step 7** to finish for the relevant $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/analysis/combine/combine.sh $id
done
````

This step will combine the alignment from the three steps into one file.

Input files:

* `$out/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_ bismark.bam`
* `$out/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_bismark.bam`
* `$out/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz_bismark.bam`
* `$out/alignment3_junctions/splitNtoD/Name.Repl.Tech.bam`

Output file: 

* `$out/alignment_combined/Name.Repl.Tech.bam`

#### Step 9: Filter bam files

Must wait for **Step 8** to finish for the relevant $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$digits`
for id in $ids
do
	$scripts/analysis/filter/filter.sh $id
done
````
This step will remove reads with >= 1/3 methylated bases. Those reads are likely to indicate problems.

Input file:

* `$out/alignment_combined/Name.Repl.Tech.bam`

Output file: 

* `$out/alignment_combined/filtered/Name.Repl.Tech.bam`

#### Step 10: Merge technical replicates

Must wait for **Step 9** to finish for all technical replicates with the same $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$((digits-1)) | sort | uniq`
for id in $ids
do
	$scripts/analysis/merge/merge.sh $id
done
````
This step will merge the technical replicates into a single file.

Input file(s):

* `$out/alignment_combined/Name.Repl.*.bam`

Output file: 

* `$out/alignment_combined/merged/Name.Repl.bam`

#### Step 11: Run bismark

Must wait for **Step 10** to finish for relevant $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$((digits-1)) | sort | uniq`
for id in $ids
do
	$scripts/bismark/bismark.sh $id
done
````
This step will run bismark for each biological replicate.

Input file:

* `$out/alignment_combined/merged/Name.Repl.bam`

Output files: 

* `$out/bismark/Name.Repl/Name.Repl.bedGraph.gz`
* `$out/bismark/Name.Repl/Name.Repl.bismark.cov.gz`

#### Step 12: Pool biological replicates

Must wait for **Step 11** to finish for all biological replicates with the same $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$((digits-2)) | sort | uniq`
for id in $ids
do
	$scripts/analysis/pool/pool.sh $id
done
````

This step will pool the biological replicates into a single file.

Input file(s):

* `$out/alignment_combined/Name.*.*.bam`

Output file: 

* `$out/alignment_combined/pooled/Name.bam`

#### Step 13: Bismark on pooled replicates

Must wait for **Step 12** to finish for the relevant $id.

````bash
ids=`ls data/*.fq.gz | cut -d'/' -f2 | cut -d'.' -f1-$((digits-2)) | sort | uniq`
for id in $ids
do
	$scripts/bismark-pool/bismark-pool.sh $id
done
````

This step will run bismark for each pooled sample.

Input file:

* `$out/alignment_combined/merged/pooled/Name.bam`

Output files: 

* `$out/bismark-pool/Name/Name.bedGraph.gz`
* `$out/bismark-pool/Name/Name.bismark.cov.gz`

### Version

The current version is 1.0. For other the versions, see the [tags on this repository](https://github.com/susbo/trans-bsseq/tags). 

### Author

* **Susanne Bornelöv** - [susbo](https://github.com/susbo)

### License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

### Citation

At the moment you can refer to the github repository [https://github.com/susbo/trans-bsseq].

