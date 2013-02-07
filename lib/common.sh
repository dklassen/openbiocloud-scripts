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

	if [ -d ${data_dir} ];
		then
		echo "WARNING: Data dir exists already data will be copied over "
		rm -rf $data_dir && mkdir -p $data_dir
	else
		mkdir -p $data_dir
	fi

	if [ -d ${db_dir} ];
	then 
		rm -rf $db_dir && mkdir -p $db_dir
	else
		mkdir -p $db_dir	
	fi 

	echo "INFO: Setup virtuoso in ${db_dir}"
	cp ${root_dir}/virtuoso.ini ${db_dir}/virtuoso.ini
	ln -s ${virtuoso_dir}/bin/virtuoso-t	${db_dir}/virtuoso-t
	ln -s ${virtuoso_dir}/bin/isql ${db_dir}/isql
}
