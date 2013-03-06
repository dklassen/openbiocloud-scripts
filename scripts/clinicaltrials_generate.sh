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
cto="https://raw.github.com/dklassen/bio2rdf-scripts/master/clinical-trials/clinicaltrials.php"

folder="${scripts}/cto"
echo "INFO: Creating folder: ${folder}"
mkdir -p $folder

if [ -f "${folder}/cto.php" ]; then
	rm "${folder}/cto.php"
fi

cd $folder
echo "INFO: Downloading from github ${cto} to cto.php"
wget --no-check-certificate -q $cto -O cto.php

if [ ! -d "${data_dir}/cto/download" ]; then 
	mkdir -p "${data_dir}/cto/download"
fi

if [ ! -d "${data_dir}/cto/data" ] ;then 
	mkdir -p "${data_dir}/cto/data"
fi

echo "INFO: Parsing CTO"
php "cto.php" process=crawl files=all indir="${data_dir}/cto/download/" outdir="${data_dir}/cto/data/"

status=$?
if [ $status -ne 0 ]; then
    echo "ERROR: CTO script died"
    exit 1
fi

build_database
generate_analytics
package
alert $1