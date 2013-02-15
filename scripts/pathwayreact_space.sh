# PathwayCommons
# KEGG
# SABIO-RK
# BioModels

#! /bin/bash
set -e
umask 0022

root_dir=$(dirname $(dirname "$(pwd)/.."))
cd $root_dir
source ./lib/functions.sh
source ./lib/common.sh

SPACE_NAME="pathwayreact_space"			# Name of the endpoint being created
data_dir=/opt/data/${SPACE_NAME}		# Where the data will be placed
db_dir=${data_dir}/virtuoso/			# Where the virtuoso db will be constructucted

scripts="${root_dir}/dataspaces/${SPACE_NAME}"
logfile="${data_dir}/${SPACE_NAME}_$(date +"%Y-%m-%d").log"

# # List of source scripts to download and run format: [ name script_url files_to_process ]
sources[0]="biomodels https://raw.github.com/dklassen/bio2rdf-scripts/master/biomodels/biomodels.php"
sources[1]="biopax https://raw.github.com/dklassen/bio2rdf-scripts/biopax/biopax/biopax.php"
sources[2]="sabiork https://raw.github.com/dklassen/bio2rdf-scripts/master/sabiork/sabiork.php"

function setup_dataspace(){
	check_virtuoso_install
	check_dependencies
	setup_data_dir
	
	touch $logfile
	echo "INFO: Logging to $logfile"

	# Directory where we are going to put everything
	if [ ! -d "$scripts" ];then
		mkdir -p $scripts
	fi
}


# Download kegg data from bio2rdf since requires paid subscription
setup_dataspace
download_kegg
generate_data
build_database
# generate_analytics
package
alert $1
