#!/bin/sh
set -e
REF=wuhCor1/wuhCor1.fa

READ1=$1
READ2=$2

if [[ "$#" -lt 2 ]]; then
	echo "
Generate covid draft assemblies from raw fastq data
Usage:
	./$(basename "$0") READ1.fastq.gz READ2.fastq.gz
	"
	exit 0
fi

PREFIX=$(basename $READ1 | rev | cut -d '.' -f 3- | rev | cut -d '_' -f 1)

# Determines number of cores your machine
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	export CORES=$SLURM_CPUS_ON_NODE
elif [[ "$OSTYPE" == "darwin"* ]]; then
	export CORES=$(sysctl -n hw.ncpu)
else
	echo "Error: apologies, only MacOS and Linux operation systems for the time being..."; exit
fi

# Perform sequence adapter trimming
bbduk="../bin/bbmap/bbduk.sh"
TRIM1=${PREFIX}.bbduk_trim_R1.fastq.gz
TRIM2=${PREFIX}.bbduk_trim_R2.fastq.gz

# bbduk - decontamination Using Kmers 
# script provided by: https://jgi.doe.gov/data-and-tools/bbtools/bb-tools-user-guide/bbduk-guide
echo "
$bbduk -Xmx4g in1=$READ1 in2=$READ2 out1=$TRIM1 out2=$TRIM2 minlen=25 qtrim=rl trimq=10 ktrim=r k=25 mink=11 hdist=1 ref=../bin/bbmap/resources/adapters.fa"
$bbduk -Xmx4g in1=$READ1 in2=$READ2 out1=$TRIM1 out2=$TRIM2 minlen=25 qtrim=rl trimq=10 ktrim=r k=25 mink=11 hdist=1 ref=../bin/bbmap/resources/adapters.fa

DIR=trim_galore_${PREFIX}
INPUT1="$DIR/${PREFIX}_val_1.fq.gz"
INPUT2="$DIR/${PREFIX}_val_2.fq.gz"

if [ command -v trim_galore &> /dev/null ]; then
	echo "Error: could not locate https://github.com/FelixKrueger/TrimGalore.git"; exit
fi

echo "
trim_galore -o $DIR --basename $PREFIX --trim-n --max_n 0 --cores 4 --paired $TRIM1 $TRIM2"
trim_galore -o $DIR --basename $PREFIX --trim-n --max_n 0 --cores 4 --paired $TRIM1 $TRIM2

# Assemble initial contigs with SPAdes 3.14.1
export PATH=/Users/eric.au/bin/SPAdes-3.14.1-Darwin/bin:$PATH
# Paper:	https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3342519/pdf/cmb.2012.0021.pdf
# Github:	https://github.com/ablab/spades
# Manual:	https://cab.spbu.ru/software/spades
if [ command -v spades.py &> /dev/null ]; then
	echo "Error: could not locate https://github.com/ablab/spades"; exit
fi

echo "
spades.py --only-assembler -o ${PREFIX}_covid_spades -t $CORES --rna -1 $INPUT1 -2 $INPUT2"
spades.py --only-assembler -o ${PREFIX}_covid_spades -t $CORES --rna -1 $INPUT1 -2 $INPUT2

DRAFT_FASTA=${PREFIX}_covid_spades/transcripts.fasta

# Perform reference guided assembly:
# Paper:	https://genomebiology.biomedcentral.com/track/pdf/10.1186/s13059-019-1829-6.pdf
# Github:	https://github.com/malonge/RagTag
# Nucmer 	http://mummer.sourceforge.net
export PATH=/Users/eric.au/miniconda3/bin:$PATH

if [ command -v ragtag.py &> /dev/null ]; then
	echo "Error: could not locate https://github.com/malonge/RagTag"; exit
fi

echo "
ragtag.py scaffold --aligner nucmer -o ${PREFIX}.covid.guided_assembly $REF $DRAFT_FASTA"
ragtag.py scaffold --aligner nucmer -o ${PREFIX}.covid.guided_assembly $REF $DRAFT_FASTA

# Simple filter for scaffolds and removed very fragmented contigs
echo "
faFilter -name=*NC_045512v2* ${PREFIX}.covid.guided_assembly/ragtag.scaffolds.fasta ${PREFIX}.covid.guided_assembly.FINAL.fa"
faFilter -name=*NC_045512v2* ${PREFIX}.covid.guided_assembly/ragtag.scaffolds.fasta ${PREFIX}.covid.guided_assembly.FINAL.fa

touch ${PREFIX}_stats.txt
rm ${PREFIX}_stats.txt

# Calculating genome size
echo "
faSize -detailed ${PREFIX}.covid.guided_assembly.FINAL.fa >> ${PREFIX}_stats.txt"
faSize -detailed ${PREFIX}.covid.guided_assembly.FINAL.fa >> ${PREFIX}_stats.txt

export PATH=/Users/eric.au/src/github.com/vertgenlab/gonomics/cmd/faGaps:$PATH

# Estimated gap regions output in BED format
echo "
faGaps -bed ${PREFIX}.covid.guided_assembly.FINAL.fa ${PREFIX}.covid.guided_assembly.FINAL.GAPS.bed"
faGaps -bed ${PREFIX}.covid.guided_assembly.FINAL.fa ${PREFIX}.covid.guided_assembly.FINAL.GAPS.bed

GAPS=$(wc -l ${PREFIX}.covid.guided_assembly.FINAL.GAPS.bed)
echo "Number of Gaps: $GAPS" >> ${PREFIX}_stats.txt
