#! /bin/bash
set -e
umask 0022

SPACE_NAME="drugspace"
data_dir=/opt/data/${SPACE_NAME}		# Where the data will be placed
db_dir=${data_dir}/virtuoso/			# Where the virtuoso db will be constructucted

root_dir=$(dirname $(dirname "$(pwd)/.."))
scripts="${root_dir}/dataspaces/${SPACE_NAME}"
logfile="${data_dir}/${SPACE_NAME}_$(date +"%Y-%m-%d").log"

cd $root_dir
source ./lib/common.sh
source ./lib/functions.sh

# Check virtuoso can be found
check_virtuoso_install
if [  $? -ne 0 ];
	then
	echo "$?"
	exit 1
fi

# Create the data directories
setup_data_dir

# Directory where we are going to put everything
if [ ! -d "$scripts" ];then
	mkdir -p $scripts
fi

sources[0]="ndc https://raw.github.com/bio2rdf/bio2rdf-scripts/master/ndc/ndc.php"
sources[1]="omim https://raw.github.com/dklassen/bio2rdf-scripts/master/omim/omim.php"
sources[2]="drugbank https://raw.github.com/dklassen/bio2rdf-scripts/drugbank/drugbank/drugbank.php"
sources[3]="sider https://raw.github.com/micheldumontier/bio2rdf-scripts/sider/sider/sider.php"
sources[4]="pharmgkb https://github.com/bio2rdf/bio2rdf-scripts/raw/master/pharmgkb/pharmgkb.php offsides"

#=========================================================================
# Start the bio2rdf scripts here
#=========================================================================

generate_data

#########################################################################
# download and convert ontologies
#########################################################################
human_phenotype="http://purl.obolibrary.org/obo/hp.owl"
disease_ontology="http://purl.obolibrary.org/obo/doid.owl"

folder="${data_dir}/ontologies/"
echo "INFO: Creating folder: ${folder}"
mkdir -p $folder

cd $folder
echo "INFO: Downloading ontologies"
wget --no-check-certificate  ${human_phenotype} -O human_phenotype.owl
rapper human_phenotype.owl > human_phenotype.nt
gzip human_phenotype.nt
rm human_phenotype.owl
echo "INFO: Done with human_phenotype ontology"

echo "INFO: Done with human_phenotype"
wget --no-check-certificate  ${disease_ontology} -O disease_ontology.owl
rapper disease_ontology.owl > disease_ontology.nt
gzip disease_ontology.nt
rm disease_ontology.owl
echo "INFO: Done with disease_ontology"
echo "INFO: Finished downloading the ontologies"

build_database
#generate_analytics
package
alert $1
