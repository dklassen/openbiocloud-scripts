#! /bin/bash
set -e
umask 0022

SPACE_NAME="clinical_space"			# Name of the endpoint being created
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
	echo "$?"
	exit 1
fi

# Create the data directories
setup_data_dir

touch $logfile
echo "INFO: Logging to $logfile"

# Directory where we are going to put everything
if [ ! -d "$scripts" ];then
	mkdir -p $scripts
fi

# List of source scripts to download and run format: [ name script_url files_to_process ]
sources[0]="clinical_trials https://raw.github.com/dklassen/bio2rdf-scripts/master/clinical-trials/clinicaltrials.php"

generate_data
build_database
# #generate_analytics
package
alert $1