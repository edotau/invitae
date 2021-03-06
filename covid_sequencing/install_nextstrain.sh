#!/bin/sh
set -e
# Wrapper script for Nextstrain SARS-CoV-2 tutorial

# Performs check to install miniconda on computer if conda does not exist in path
if ! command -v conda &> /dev/null; then
	echo "conda was not found..."
	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
		curl https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh --output miniconda_install_LINUX.sh ; bash ./miniconda_install_LINUX.sh
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		curl https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh --output miniconda_install_MACOS.sh; bash ./miniconda_install_MACOS.sh
	else
		echo "Error: apologies, I only support MacOS and Linux operation systems for the time being..."
		exit
	fi
fi
source "$(conda info --base)/etc/profile.d/conda.sh" ; conda activate ; conda activate

YML=${PWD}/nextstrain.yml

if [ -d "$(conda info --base)/envs/nextstrain" ]; then # check if the directory is there
	echo "nextstrain env already exists!
conda activate nextstrain"
	conda activate nextstrain
else
	echo "installing conda nextstrain env..."
	# Setup your Nextstrain environment
	echo "
	curl http://data.nextstrain.org/nextstrain.yml --compressed -o $YML"
	curl http://data.nextstrain.org/nextstrain.yml --compressed -o $YML

	echo "
	conda env create -f $YML"
	conda env create -f $YML

	echo "
	conda activate nextstrain"
	conda activate nextstrain

	echo "
	npm install --global auspice"
	npm install --global auspice
fi

# Determines number of cores your machine has
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	export CORES=$SLURM_CPUS_ON_NODE
elif [[ "$OSTYPE" == "darwin"* ]]; then
	export CORES=$(sysctl -n hw.ncpu)
else
	echo "Error: Error: apologies, I only support MacOS and Linux operation systems for the time being..."
fi

# Run a basic analysis with example data
if ! [ -d "ncov" ]; then # check if the directory is there
	echo "git clone https://github.com/nextstrain/ncov.git"
	git clone https://github.com/nextstrain/ncov.git
	cd ncov

	# Runs analysis pipeline on interesting dataset:
	echo "
	gzip -d -c data/example_sequences.fasta.gz > data/example_sequences.fasta"
	gzip -d -c data/example_sequences.fasta.gz > data/example_sequences.fasta

	echo "
	snakemake --cores $CORES --profile ./my_profiles/getting_started"
	snakemake --cores $CORES --profile ./my_profiles/getting_started

	echo "
	snakemake --cores $CORES --profile ./my_profiles/getting_started"
	snakemake --cores $CORES --profile ./my_profiles/getting_started
else
	cd ncov
fi

echo "
auspice view & open http://localhost:4000"
auspice view & sleep 5s; open "http://localhost:4000"

echo "When finished with broswer run:
kill \$(lsof -t -i :4000)"
