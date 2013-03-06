#! /bin/bash
set -e
umask 0022

# !IMPORTANT: THIS needs to come first
SPACE_NAME="pathwayreact_space"	

root_dir=$(dirname $(dirname "$(pwd)/.."))
cd $root_dir
source ./lib/common.sh
source ./lib/functions.sh

mkdir -p "${root_dir}/dataspaces"
scripts="${root_dir}/dataspaces/${SPACE_NAME}"

logfile="${data_dir}/${SPACE_NAME}_$(date +"%Y-%m-%d").log"

# # List of source scripts to download and run format: [ name script_url files_to_process ]
sources[0]="biomodels https://raw.github.com/dklassen/bio2rdf-scripts/master/biomodels/biomodels.php"
sources[1]="biopax https://raw.github.com/dklassen/bio2rdf-scripts/biopax/biopax/biopax.php"
sources[2]="sabiork https://raw.github.com/dklassen/bio2rdf-scripts/master/sabiork/sabiork.php"

check_virtuoso_install
check_dependencies
setup_data_dir

download_kegg
generate_data
build_database
generate_analytics
package
alert $1
