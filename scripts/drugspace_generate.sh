#! /bin/bash

SPACE_NAME="drugspace"

root_dir=$(dirname $(dirname "$(pwd)/.."))
scripts="${root_dir}/dataspaces/${SPACE_NAME}"
logfile="/tmp/${SPACE_NAME}_$(date +"%Y-%m-%d").log"

cd $root_dir
source ./lib/functions.sh

# Start fresh
rm -rf $scripts

# Directory where we are going to put everything
if [ ! -d "$scripts" ];then
	mkdir -p $scripts
fi

sources[0]="ndc https://raw.github.com/bio2rdf/bio2rdf-scripts/master/ndc/ndc.php"
sources[1]="omim https://raw.github.com/dklassen/bio2rdf-scripts/master/omim/omim.php"
sources[2]="drugbank https://raw.github.com/dklassen/bio2rdf-scripts/master/drugbank/drugbank.php"
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

folder="${scripts}/ontologies/"
echo "INFO: Creating folder: ${folder}"
mkdir -p $folder

cd $folder
echo "INFO: Downloading ontologies"
wget --no-check-certificate -q "${human_phenotype}" "human_phenotype.owl"
echo "INFO: Done with human_phenotype"
wget --no-check-certificate -q "${disease_ontology}" "disease_ontology.owl"
echo "INFO: Done with disease_ontology"
echo "INFO: Finished downloading the ontologies"

build_database
#generate_analytics
package
alert $1



