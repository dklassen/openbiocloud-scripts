virtuoso_dir=/usr/local/virtuoso-opensource/		# The default location for virtuoso install

isql=${db_dir}isql
isql_cmd="${isql} localhost:1111 -U dba"
isql_pass="-P dba"

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


function setup_data_dir(){

	# Create directory if none exists
	if [ ! -d ${data_dir} ];
		then
		mkdir -p $data_dir
	fi

	# Hard reset the virtuoso directory
	if [ -d ${db_dir} ];
	then 
		rm -rf $db_dir && mkdir -p $db_dir
	else
		mkdir -p $db_dir	
	fi 

	echo "INFO: Setup virtuoso in ${db_dir}"
	cp ${root_dir}/virtuoso.ini ${db_dir}/virtuoso.ini
	ln -s ${virtuoso_dir}/bin/virtuoso-t ${db_dir}/virtuoso-t
	ln -s ${virtuoso_dir}/bin/isql ${db_dir}/isql
}

function download_kegg(){
	# Download kegg data from bio2rdf since requires paid subscription
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
		gzip .
	fi
}
