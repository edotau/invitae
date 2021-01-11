#!/bin/sh
export PATH=/Users/eric.au/bin/SPAdes-3.14.1-Darwin/bin:$PATH

REF=wuhCor1/wuhCor1.fa
READ1=$1
READ2=$2

if [[ "$#" -lt 2 ]]
then
	echo "Usage:
	./$(basename "$0") READ1.fastq.gz READ2.fastq.gz"
	exit 0
	fi

PREFIX=$(basename $READ1  | rev | cut -d '.' -f 3- | rev | cut -d '_' -f 1)
CORES=$(sysctl -n hw.ncpu)

echo "
spades.py --only-assembler -o ${PREFIX}_covid_spades -t $CORES --rna -1 $READ1 -2 $READ2"
spades.py --only-assembler -o ${PREFIX}_covid_spades -t $CORES --rna -1 $READ1 -2 $READ2

DRAFT_FASTA=${PREFIX}_covid_spades/transcripts.fasta
export PATH=/Users/eric.au/miniconda3/bin:$PATH

echo "
ragtag.py scaffold --aligner nucmer -o ${PREFIX}.covid.guided_assembly $REF $DRAFT_FASTA"
ragtag.py scaffold --aligner nucmer -o ${PREFIX}.covid.guided_assembly $REF $DRAFT_FASTA

echo "
faFilter -name=*NC_045512v2* ${PREFIX}.covid.guided_assembly/ragtag.scaffolds.fasta ${PREFIX}.covid.guided_assembly.FINAL.fa"
faFilter -name=*NC_045512v2* ${PREFIX}.covid.guided_assembly/ragtag.scaffolds.fasta ${PREFIX}.covid.guided_assembly.FINAL.fa

touch ${PREFIX}_stats.txt
rm ${PREFIX}_stats.txt

echo "
faSize -detailed ${PREFIX}.covid.guided_assembly.FINAL.fa >> ${PREFIX}_stats.txt"
faSize -detailed ${PREFIX}.covid.guided_assembly.FINAL.fa >> ${PREFIX}_stats.txt

export PATH=/Users/eric.au/src/github.com/vertgenlab/gonomics/cmd/faGaps:$PATH

echo "
faGap -bed ${PREFIX}.covid.guided_assembly.FINAL.fa ${PREFIX}.covid.guided_assembly.FINAL.GAPS.bed"
faGap -bed ${PREFIX}.covid.guided_assembly.FINAL.fa ${PREFIX}.covid.guided_assembly.FINAL.GAPS.bed

GAPS=$(wc -l ${PREFIX}.covid.guided_assembly.FINAL.GAPS.bed)
echo "Number of Gaps: $GAPS" >> ${PREFIX}_stats.txt
