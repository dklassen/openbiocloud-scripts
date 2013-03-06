#! /bin/bash
set -e
umask 0022

SPACE_NAME="biomedical_space"			# Name of the endpoint being created

root_dir=$(dirname $(dirname "$(pwd)/.."))
cd $root_dir
source ./lib/common.sh
source ./lib/functions.sh

# Check virtuoso can be found
check_virtuoso_install
setup_data_dir
check_dependencies


if [ ! -d "$scripts" ];then
	mkdir -p $scripts
fi

# List of source scripts to download and run format: [ name script_url files_to_process ]
sources[0]="ctd https://raw.github.com/bio2rdf/bio2rdf-scripts/master/ctd/ctd.php"
sources[1]="pharmgkb https://github.com/bio2rdf/bio2rdf-scripts/raw/master/pharmgkb/pharmgkb.php"
sources[2]="mgi https://raw.github.com/dklassen/bio2rdf-scripts/mgi/mgi/mgi.php"

mysql_pass="penguinsdontfly"
mysql_user='root'

# Install mysql and chembldb
mysql_pkg=$(dpkg -s mysql-server | grep Status | cut -f 4 -d ' ')
if [ "$mysql_pkg" != "installed" ];then
	echo "INFO: Installing mysql"
    sudo apt-get update
    echo "$mysql_pass" | $sudo apt-get -y -qq install mysql-server
else
	echo "INFO: MYSQL is installed"
fi

if [ $RESET -eq 0 ]; then
	echo "INFO: Dropping ChEMBL database"
	$(mysql --user=$mysql_user --password=$mysql_pass --batch --skip-column-names -e "DROP DATABASE chembl;")
fi

# Set up mysql database
echo "INFO: Checking if ChEMBL database is installed"
DBEXISTS=$(mysql --user=$mysql_user --password=$mysql_pass --batch --skip-column-names -e "SHOW DATABASES LIKE '"chembl"';" | grep "chembl" > /dev/null; echo "$?")
if [ $DBEXISTS -eq 1 ];then
	echo "INFO: Missing ChEMBL database"
	mysql --user=$mysql_user --password=$mysql_pass -e 'create database chembl'

	echo 'INFO: Creating chembl download directory'
	chembl="ftp://ftp.ebi.ac.uk/pub/databases/chembl/ChEMBLdb/latest/chembl_15_mysql.tar.gz"
	mkdir -p $data_dir/chembl/ && cd $_
	wget $chembl
	tar -xvf chembl_15_mysql.tar.gz 
	cd chembl_15_mysql/
	mysql --user=$mysql_user --password=$mysql_pass -h localhost chembl < chembl_15.mysqldump.sql
else
	echo "INFO: ChEMBL is installed."
fi

# Run the chembl script for assays and compounds
# Using the chembl branch from dklassen
if [ ! -d "$data_dir/chembl" ]; then
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
fi

#download_pubmed_from_bio2rdf
#generate_data
#build_database
generate_analytics
#package
#alert $1
