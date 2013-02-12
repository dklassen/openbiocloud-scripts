#! /bin/bash
set -e
umask 0022

SPACE_NAME="biomedical_space"			# Name of the endpoint being created
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

setup_data_dir
touch $logfile
echo "INFO: Logging to $logfile"

if [ ! -d "$scripts" ];then
	mkdir -p $scripts
fi

# List of source scripts to download and run format: [ name script_url files_to_process ]
sources[0]="ctd https://raw.github.com/bio2rdf/bio2rdf-scripts/master/ctd/ctd.php"
sources[1]="pharmgkb https://github.com/bio2rdf/bio2rdf-scripts/raw/master/pharmgkb/pharmgkb.php"
sources[2]='mgi https://raw.github.com/bio2rdf/bio2rdf-scripts/master/mgi/mgi.php'

mysql_pass="penguinsdontfly"
mysql_user='root'

# Install mysql and chembldb
mysql_pkg=$(dpkg -s mysql-server | grep Status | cut -f 4 -d ' ')
if [ "$mysql_pkg" != "installed" ];then
	echo "INFO: Installing mysql"
	echo "$mysql_pass" | $sudo apt-get install mysql-server
fi

# Set up mysql database
chembl_is_installed=$(mysql -u${mysql_user} -p${mysql_pass} -e "SHOW DATABASES LIKE 'chembl'" | grep chembl)
if [ $chembl_is_installed -ne 'chembl' ];then
	mysql -u$mysql_user -p $mysql_pass -e 'create database chembl'

	echo 'INFO: Creating chembl download directory'
	chembl="ftp://ftp.ebi.ac.uk/pub/databases/chembl/ChEMBLdb/latest/chembl_15_mysql.tar.gz"
	mkdir -p $data_dir/chembl/ && cd $_
	wget $chembl
	tar -xvf chembl_15_mysql.tar.gz 
	cd chembl_15_mysql/
	mysql -u$mysql_user -p -h localhost chembl < chembl_15_mysql/chembl_15.mysqldump.sql 
fi

# Run the chembl script for assays and compounds
# Using the chembl branch from dklassen
chembl_script="https://raw.github.com/dklassen/bio2rdf-scripts/chembl/chembl/chembl.php"
folder="${scripts}/chembl"
echo "INFO: Creating folder: ${folder}"
mkdir -p $folder

if [ -f "${folder}/chembl.php" ]; then
	rm "${folder}/chembl.php"
fi

cd $folder
echo "INFO: Downloading from github $chembl_script to chembl.php"
wget --no-check-certificate -q $chembl_script -O chembl.php

if [ ! -d "${data_dir}/$1/data" ] ;then 
	mkdir -p "${data_dir}/chembl/data"
fi

echo "INFO: Running chembl parser for assay information"
php chembl.php files=assays outdir="${data_dir}/chembl/data/" user=$mysql_user pass=$mysql_pass db_name='chembl'
php chembl.php files=compounds outdir="${data_dir}/chembl/data/" user=$mysql_user pass=$mysql_pass db_name='chembl'
php chembl.php files=targets outdir="${data_dir}/chembl/data/" user=$mysql_user pass=$mysql_pass db_name='chembl'

status=$?
if [ $status -ne 0 ]; then
    echo "ERROR: chembl script died while generating assay data" 
fi

download_pubmed_from_bio2rdf
generate_data
build_database
# generate_analytics
package
alert $1