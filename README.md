---
output: pdf_document
---
# Analysis of transcriptomic BS-seq data

Here we describe the analysis of transcriptomic BS-seq data. This approach was used for the Sajini *et al.* (2019).

## Getting Started

These instructions will briefly describe how to analyse transcriptomic BS-seq data. You will need access to a computer cluster or similar to run some of the following steps.

### Prerequisites

This pipeline uses many external tools and will only run on a UNIX-like environment.

Required software:

* [Perl](https://www.perl.org)
* [bedtools](http://bedtools.readthedocs.io/en/latest/content/installation.html)
* DeepTools
* AWK

These should all be standard tools and already installed on most computer clusters.

### Installation

Download all the script templates files.

## Running the analysis

The analysis assumes that you keep your scripts, logs and raw data in the `$pwd` directory and that you are saving the output to the `$path` directory.

### Copying the raw data
Firstly, create a `$pwd/data` directory and put the samples there after giving them meaningful names. In this example, we have 20 files named:
`Undiff.[1-5].[78].fq.gz` and `Diff.[1-5].[78].fq.gz`.

The sample names must have at least three fields separateby by a dot ".", the first is the group/treatment (Undiff or Diff), the second the biological replicate (1-5) and the third is the technical replicate (7-8). The number of fields must be saved in the `$digits` variable, any additonal fields to be put into the beginning of the file names (e.g., `Extra-info.Diff.1.7.fq.gz`) and will simply be ignored.

### Preparing each script from a template
Each step in the pipeline has a separate template file with the neccessary commands. In order to run it, you need to create folder (typically named after the script) and copy the script to that folder and add the correct `$pwd`, `$path` and `$digits` (here 3) to that script before running it.

The following bash function was used to copy and rename each template file:

````bash
function prepare {
   # Copy each script only once
   if [ "${done_prepare[$2]}" != "1" ]; then
      echo Preparing $2...
      mkdir -p $pwd/$1
      mkdir -p $pwd/$1/log
      cp templates/$2.template $pwd/$1/$2.sh
      sed -i "s|__PREFIX__|$prefix|g" "$pwd/$1/$2.sh"
      sed -i "s|__PWD__|$pwd|g" "$pwd/$1/$2.sh"
      sed -i "s|__DIGITS__|$digits|g" "$pwd/$1/$2.sh"
      # Copy additional scripts and data
      if [ -d "templates/$2" ]; then
         cp -r templates/$2/* $pwd/$1
      fi
      done_prepare[$2]="1"
   fi
}
````

The first argument is the target folder and the second is the template file name. The steps below assume that each template has been prepared according to these instructions.

````bash
# Reset done_prepare to overwrite any previous files
unset done_prepare; declare -A done_prepare

# Prepare each template, remember to set $path, $pwd and $digits before running this.
prepare fastqc fastqc
prepare trim trim
prepare alignment alignment
prepare trim2 trim2
prepare alignment2 alignment2
prepare alignment3_junctions alignment3_junctions
prepare analysis/misc/split3 split3
prepare analysis/misc/combine combine
prepare analysis/misc/filter filter
prepare analysis/misc/merge merge
prepare bismark bismark
prepare analysis/misc/pool pool
prepare bismark-pool bismark-pool
````

### Running the scripts

It is assumed in all examples below, that a sample is named according to the `Name.Repl.Tech.fq.gz` structure.

#### Step 1: Quality control using FastQC
````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$digits`
for id in $ids
do
	$pwd/fastqc/fastqc.sh $id
done
````
This will produce a FastQC report for each raw file.

Input file:

* `$pwd/data/Name.Repl.Tech.fq.gz`

Output file: 

* `$prefix/fastqc/Name.Repl.Tech.fq_fastqc.html`

#### Step 2: Read trimming with Trim galore!

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$digits`
for id in $ids
do
	$pwd/trim/trim.sh $id
done
````

This will remove sequencing adapters and exclude reads with length <20.

Input file:

* `$pwd/data/Name.Repl.Tech.fq.gz`

Output file: 

* `$prefix/trim/Name.Repl.Tech_trimmed.fq.gz`

#### Step 3: Alignment, step 1

Must wait for **Step 2** to finish for the relevant $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$digits`
for id in $ids
do
	$pwd/alignment/alignment.sh $id
done
````
This will align the trimmed reads to the reference genome and also save the unmapped and ambiguous reads.

Input file:

* `$prefix/trim/Name.Repl.Tech_trimmed.fq.gz`

Output files: 

* `$prefix/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_ bismark.bam`
* `$prefix/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_unmapped_reads.fq.gz`
* `$prefix/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_ambiguous_reads.fq.gz`

#### Step 4: Read trimming, step 2

Must wait for **Step 3** to finish for the relevant $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$digits`
for id in $ids
do
	$pwd/trim2/trim2.sh $id
done
````
This will remove the three last nucleotides from the unmapped and ambiguous reads.

Input files:

* `$prefix/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_unmapped_reads.fq.gz`
* `$prefix/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_ambiguous_reads.fq.gz`

Output files: 

* `$prefix/trim2/unmapped/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz`
* `$prefix/trim2/ambiguous/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz`

#### Step 5: Alignment, step 2

Must wait for **Step 4** to finish for the relevant $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$digits`
for id in $ids
do
	$pwd/alignment2/alignment2.sh $id
done
````
This will attempt to align the previously unaligned and ambiguous reads.

Input files:

* `$prefix/trim2/unmapped/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz`
* `$prefix/trim2/ambiguous/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz`

Output files: 

* `$prefix/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_bismark.bam`
* `$prefix/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_ambiguous_reads.fq.gz`
* `$prefix/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_unmapped_reads.fq.gz`
* `$prefix/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz_bismark.bam`
* `$prefix/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz_ambiguous_reads.fq.gz`
* `$prefix/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz_unmapped_reads.fq.gz`

#### Step 6: Alignment, step 3

Must wait for **Step 5** to finish for the relevant $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$digits`
for id in $ids
do
	$pwd/alignment3_junctions/alignment3_junctions.sh $id
done
````

This will attempt to align the previously twice unaligned reads to splice junctions.

Input file:

* `$prefix/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_unmapped_reads.fq.gz`

Output file: 

* `$prefix/alignment3_junctions/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.un.fq.gz_bismark.bam`

#### Step 7: Split3

Must wait for **Step 6** to finish for the relevant $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$digits`
for id in $ids
do
	$pwd/analysis/misc/split3.sh $id
done
````

This step will remap the splice junction alignments to genomic coordinates and replace N in the CIGAR string with D for compatibility with the *bismark_methylation_extractor*.

Input file:

* `$prefix/alignment3_junctions/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.un.fq.gz_bismark.bam`

Output file: 

* `$prefix/alignment3_junctions/splitNtoD/Name.Repl.Tech.bam`

#### Step 8: Combine bam files

Must wait for **Step 7** to finish for the relevant $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$digits`
for id in $ids
do
	$pwd/analysis/misc/combine.sh $id
done
````

This step will combine the alignment from the three steps into one file.

Input files:

* `$prefix/alignment/Name.Repl.Tech/Name.Repl.Tech_trimmed.fq.gz_ bismark.bam`
* `$prefix/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.un.fq.gz_bismark.bam`
* `$prefix/alignment2/Name.Repl.Tech/Name.Repl.Tech/Name.Repl.Tech.ambig.fq.gz_bismark.bam`
* `$prefix/alignment3_junctions/splitNtoD/Name.Repl.Tech.bam`

Output file: 

* `$prefix/alignment_combined/Name.Repl.Tech.bam`

#### Step 9: Filter bam files

Must wait for **Step 8** to finish for the relevant $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$digits`
for id in $ids
do
	$pwd/analysis/misc/filter.sh $id
done
````
This step will remove reads with >= 1/3 methylated bases. Those reads are likely to indicate problems.

Input file:

* `$prefix/alignment_combined/Name.Repl.Tech.bam`

Output file: 

* `$prefix/alignment_combined/filtered/Name.Repl.Tech.bam`

#### Step 10: Merge technical replicates

Must wait for **Step 9** to finish for all technical replicates with the same $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$((digits-1)) | sort | uniq`
for id in $ids
do
	$pwd/analysis/misc/merge.sh $id
done
````
This step will merge the technical replicates into a single file.

Input file(s):

* `$prefix/alignment_combined/Name.Repl.*.bam`

Output file: 

* `$prefix/alignment_combined/merged/Name.Repl.bam`

#### Step 11: Run bismark

Must wait for **Step 10** to finish for relevant $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$((digits-1)) | sort | uniq`
for id in $ids
do
	$pwd/bismark/bismark.sh $id
done
````
This step will run bismark for each biological replicate.

Input file:

* `$prefix/alignment_combined/merged/Name.Repl.bam`

Output files: 

* `$prefix/bismark/Name.Repl/Name.Repl.bedGraph.gz`
* `$prefix/bismark/Name.Repl/Name.Repl.bismark.cov.gz`

#### Step 12: Pool biological replicates

Must wait for **Step 11** to finish for all biological replicates with the same $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$((digits-2)) | sort | uniq`
for id in $ids
do
	$pwd/analysis/misc/pool.sh $id
done
````

This step will pool the biological replicates into a single file.

Input file(s):

* `$prefix/alignment_combined/Name.*.*.bam`

Output file: 

* `$prefix/alignment_combined/pooled/Name.bam`

#### Step 13: Bismark on pooled replicates

Must wait for **Step 12** to finish for the relevant $id.

````bash
ids=`ls ../data/*.fq.gz | cut -d'/' -f3 | cut -d'.' -f1-$((digits-2)) | sort | uniq`
for id in $ids
do
	$pwd/bismark-pool/bismark-pool.sh $id
done
````

This step will run bismark for each pooled sample.

Input file:

* `$prefix/alignment_combined/merged/pooled/Name.bam`

Output files: 

* `$prefix/bismark-pool/Name/Name.bedGraph.gz`
* `$prefix/bismark-pool/Name/Name.bismark.cov.gz`

### Version

The current version is 1.0. For other the versions, see the [tags on this repository](https://github.com/your/project/tags). 

### Authors

* **Susanne Bornelöv** - [susbo](https://github.com/susbo)

### License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

### Citation

At the moment you can refer to the github repository [https://github.com/susbo/trans-bsseq].

