data_dir=/opt/data/${SPACE_NAME}		# Where the data will be placed
db_dir=${data_dir}/virtuoso/			# Where the virtuoso db will be constructucted
scripts="${root_dir}/dataspaces/${SPACE_NAME}"
logfile="${data_dir}/log/${SPACE_NAME}_$(date +"%Y-%m-%d").log"

virtuoso_dir=/usr/local/virtuoso-opensource/		# The default location for virtuoso install
isql=${db_dir}isql
isql_cmd="${isql} localhost:1111 -U dba"
isql_pass="-P dba"

# location of the solr server
SOLR=http://hcls01.sindice.net:8983/solr

# Check if there is a virtuoso install
function check_virtuoso_install(){
	if [ -d "$virtuoso_dir" ];
		then
		echo "INFO: Found virtuoso directory"
		return 0
	else
		echo "ERROR: No Virtuoso directory found"
		exit 1
	fi
}

function install_rapper(){ 
echo "INFO: Installing rapper "
 apt-get -y -qq install raptor-utils
}

function check_dependencies(){
	if [ ! -d "${root_dir}/dataspaces/arc2" ]; then
		cd ${root_dir}/dataspaces/
		wget https://github.com/semsol/arc2/tarball/master -O arc.tar.gz
		tar -xvf arc.tar.gz
		mv semsol-arc2-*/ arc2/
	fi

	# We need the php-lib one directory up to run scripts
	if [ ! -d "${root_dir}/dataspaces/php-lib" ]; then
		previous=$(pwd)
		cd "${root_dir}/dataspaces/"
		wget -q https://github.com/dklassen/php-lib/archive/master.zip -O rdfapi.zip
		unzip rdfapi.zip && rm rdfapi.zip
		mv php-lib-master/ php-lib/
		cd $previous
	fi
}

function setup_data_dir(){

	db_dir=${data_dir}/virtuoso/

	# Create directory if none exists
	if [ ! -d ${data_dir} ];
		then
		mkdir -p $data_dir

	fi

	# create the log directory if it doesn't exist
	if [ ! -d "${data_dir}/log" ];
		then
		mkdir -p "${data_dir}/log"
	fi

	touch $logfile
echo "INFO: Logging to $logfile"

	# Hard reset the virtuoso directory
	if [ -d ${db_dir} ];
	then 
		rm "$db_dir"{virtuoso-t,virtuoso.ini,isql}
    else
        mkdir $db_dir
    fi 

	echo "INFO: Setup virtuoso in ${db_dir}"
	cp ${root_dir}/virtuoso.ini ${db_dir}virtuoso.ini
	ln -s ${virtuoso_dir}bin/virtuoso-t ${db_dir}virtuoso-t
	ln -s ${virtuoso_dir}bin/isql ${db_dir}isql
}

# Download pubmed from bio2rdf servers 
function download_pubmed_from_bio2rdf(){
	if [ ! -d  ${data_dir}/pubmed/ ]; then
		pubmed="http://download.bio2rdf.org/release/2/pubmed/"
		mkdir -p ${data_dir}/pubmed/data/ && cd $_
		wget -r -nH -np ${pubmed}
		find ${data_dir}/pubmed/data/release -name '*.nt.gz' -exec cp {} ./ \;
		rm -rf ${data_dir}/pubmed/data/release
	fi
}

# Download kegg data from bio2rdf since requires paid subscription
function download_kegg(){
	if [  "$(ls -A  ${data_dir}/kegg/)" ]; then
		echo "INFO: KEGG data exists ${data_dir}/kegg/"
	else
		echo "INFO: Downloading KEGG from http://download.bio2rdf.org/release/2/kegg/kegg.nt.tar.gz"
	if [ ! -d "${data_dir}/kegg/" ]; then
		mkdir -p "${data_dir}/kegg/" 
	fi
		cd "${data_dir}/kegg/"
		wget -q http://download.bio2rdf.org/release/2/kegg/kegg.nt.tar.gz -O kegg.nt.tar.gz
		tar -xvf kegg.nt.tar.gz
		gzip ./*
		rm kegg.nt.tar.gz
	fi
}
