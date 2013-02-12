# HGNC (mammalian homology)
# NCBI Gene (gene, protein, mrna)
# NCBI Taxonomy (organism)
# iRefIndex (protein-protein interactions)
# Homologene (orthology)
# Interpro (domain)
# GOA
# KEGG

#! /bin/bash
set -e
umask 0022

SPACE_NAME="biomolecular_space"			# Name of the endpoint being created
data_dir=/opt/data/${SPACE_NAME}		# Where the data will be placed
db_dir=${data_dir}/virtuoso/			# Where the virtuoso db will be constructucted

root_dir=$(dirname $(dirname "$(pwd)/.."))
scripts="${root_dir}/dataspaces/${SPACE_NAME}"
logfile="${data_dir}/${SPACE_NAME}_$(date +"%Y-%m-%d").log"

cd $root_dir
source ./lib/functions.sh
source ./lib/common.sh

# Check virtuoso can be found
check_virtuoso_install
if [  $? -ne 0 ];
	then
	exit 1
fi

# Create the data directories
setup_data_dir

touch $logfile
echo "INFO: Logging to $logfile"

# # Directory where we are going to put everything
if [ ! -d "$scripts" ];then
	mkdir -p $scripts
fi

# # List of source scripts to download and run format: [ name script_url files_to_process ]
sources[0]="ncbi_gene https://raw.github.com/bio2rdf/bio2rdf-scripts/master/gene/entrez_gene.php"
sources[1]='ncbi_taxonomy https://github.com/bio2rdf/bio2rdf-scripts/blob/master/taxonomy/ncbi_taxonomy_parser.php'
sources[2]="irefindex https://raw.github.com/bio2rdf/bio2rdf-scripts/master/irefindex/irefindex.php"
sources[3]="homologene https://raw.github.com/bio2rdf/bio2rdf-scripts/master/homologene/homologene.php"
sources[4]="interpro https://raw.github.com/bio2rdf/bio2rdf-scripts/master/interpro/interpro.php"
sources[5]="goa https://github.com/bio2rdf/bio2rdf-scripts/blob/master/goa/goa.php"

# We need the php-lib one directory up to run scripts
if [ ! -d "${root_dir}/dataspaces/php-lib" ]; then
	previous=$(pwd)
	cd "${root_dir}/dataspaces/"
	wget -q https://github.com/micheldumontier/php-lib/archive/master.zip -O rdfapi.zip
	unzip rdfapi.zip && rm rdfapi.zip
	mv php-lib-master/ php-lib/
	cd $previous
fi

# HGNC doesn't take the files parameter need a custom solution
hgnc="https://raw.github.com/bio2rdf/bio2rdf-scripts/master/hgnc/hgnc.php"

folder="${scripts}/hgnc"
echo "INFO: Creating folder: ${folder}"
mkdir -p $folder

if [ -f "${folder}/hgnc.php" ]; then
	rm "${folder}/hgnc.php"
fi

cd $folder
echo "INFO: Downloading from github ${hgnc} to $hgnc.php"
wget --no-check-certificate -q $hgnc -O hgnc.php

if [ ! -d "${data_dir}/hgnc/download" ]; then 
	mkdir -p "${data_dir}/hgnc/download"
fi

if [ ! -d "${data_dir}/hgnc/data" ] ;then 
	mkdir -p "${data_dir}/hgnc/data"
fi

echo "INFO: Parsing HGNC"
php "hgnc.php" indir="${data_dir}/hgnc/download/" outdir="${data_dir}/hgnc/data/"

status=$?
if [ $status -ne 0 ]; then
    echo "ERROR: HGNC script died" 
fi

# Download kegg data from bio2rdf since requires paid subscription
download_kegg
generate_data
build_database
#generate_analytics
package
alert $1