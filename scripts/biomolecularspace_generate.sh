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

# touch $logfile
# echo "INFO: Logging to $logfile"

# # Directory where we are going to put everything
if [ ! -d "$scripts" ];then
	mkdir -p $scripts
fi

# # List of source scripts to download and run format: [ name script_url files_to_process ]
sources[0]="hgnc https://raw.github.com/bio2rdf/bio2rdf-scripts/master/hgnc/hgnc.php"
sources[1]="ncbi_gene https://raw.github.com/bio2rdf/bio2rdf-scripts/master/gene/entrez_gene.php"
sources[2]='ncbi_taxonomy https://github.com/bio2rdf/bio2rdf-scripts/blob/master/taxonomy/ncbi_taxonomy_parser.php'
sources[3]="irefindex https://raw.github.com/bio2rdf/bio2rdf-scripts/master/irefindex/irefindex.php"
sources[4]="homologene https://raw.github.com/bio2rdf/bio2rdf-scripts/master/homologene/homologene.php"
sources[5]="interpro https://raw.github.com/bio2rdf/bio2rdf-scripts/master/interpro/interpro.php"
sources[6]="goa https://github.com/bio2rdf/bio2rdf-scripts/blob/master/goa/goa.php"

# Download kegg data from bio2rdf since requires paid subscription
if [ ! -d ${data_dir}/kegg/ ]; then
	mkdir -p ${data_dir}/kegg && $_
	wget -q http://download.bio2rdf.org/release/2/kegg/kegg.nt.tar.gz -O kegg.nt.tar.gz
	tar -xvf kegg.nt.tar.gz
fi

generate_data
build_database
generate_analytics
package
alert $1