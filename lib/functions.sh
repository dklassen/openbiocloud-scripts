

#####################################################################################
# could use lsof to check the http port if there is a webservice running?
#####################################################################################
function virtuoso_status(){
	local _virtuoso_status=$1
 	local _status_result=$(ps aux | grep -v grep | grep virtuoso-t | awk '{print $1}')
	if [ $_status_result ]; then
		_status_result=true
	else
		_status_result=false
	fi

	eval $_virtuoso_status="'$_status_result'" 
}

###################################################################################
# $1 -> name of the script
# $2 -> url for script
##################################################################################
function setup(){

	# We need the php-lib one directory up to run scripts
	if [ ! -d "${root_dir}/dataspaces/php-lib" ]; then
		previous=$(pwd)
		cd "${root_dir}/dataspaces/"
		wget -q https://github.com/micheldumontier/php-lib/archive/master.zip -O rdfapi.zip
		unzip rdfapi.zip && rm rdfapi.zip
		mv php-lib-master/ php-lib/
		cd $previous
	fi

	folder="${scripts}/${1}"

	if [ ! -d "${data_dir}/$1" ];then
		echo "INFO: Creating folder: ${folder}"
		mkdir -p $folder

		if [ -f "${folder}/$1.php" ]; then
			rm "${folder}/$1.php"
		fi

		cd $folder
		echo "INFO: Downloading from github ${2} to ${1}.php"
		wget --no-check-certificate -q $2 -O $1.php

		if [ ! -d "${data_dir}/$1/download" ]; then 
			mkdir -p "${data_dir}/$1/download"
		fi

		if [ ! -d "${data_dir}/$1/data" ] ;then 
			mkdir -p "${data_dir}/$1/data"
		fi

		if [ "$3" == "" ];then
			echo "INFO: Running $1.php"
			php "${1}.php" files=all indir="${data_dir}/$1/download/" outdir="${data_dir}/$1/data/"
		else
			echo "INFO: Running with files flag set to $3"
			php "${1}.php" files=${3} indir="${data_dir}/$1/download/" outdir="${data_dir}/$1/data/" $4
		fi

		status=$?
	    if [ $status -ne 0 ]; then
	        echo "ERROR: Current script ${1} died" 
	    fi
	else
		echo "INFO: Directory exists not going to generate new data"
	fi
}
##########################################################################
# run the passed in command through the virtuoso isql interface
# params : isql command
##########################################################################
function run_cmd(){

echo "INFO: Running virtuoso command: $1"

${isql_cmd} ${isql_pass} <<EOF &> $logfile
	$1;
	exit;
EOF

}

##########################################################################
# start new rdf_loader as background job
##########################################################################
function rdf_loader_run(){
   ${isql_cmd} ${isql_pass} verbose=on echo=on errors=stdout banner=off prompt=off exec="rdf_loader_run(); exit;"
}

###########################################################################
# Shutdown a virtuoso instance
###########################################################################
function virtuoso_shutdown(){

   ${isql_cmd} ${isql_pass} verbose=on echo=on errors=stdout banner=off prompt=off exec="shutdown(); exit;" &
    
    tail -n 0 -F "${virtuoso_log}" | while read LOGLINE
	do
        echo $LOGLINE
		[[ "${LOGLINE}" == *"Server shutdown complete"* ]] && echo "Virtuoso is shutdown gracefully" && pkill -P $$ tail
	done

}

#########################################################################
# generate the data 
# parameter : array of tab deliminated name\turl pairs
#########################################################################
function generate_data(){
	
	for i in "${sources[@]}"
	do
		name=`echo $i | awk '{print $1}'`
		url=`echo $i | awk '{print $2}'`
		files=`echo $i | awk '{print $3}'`
		extra=`echo $i | awk '{print $4}'`

		setup $name $url $files $extra
	done
}

########################################################################
# Generate a virtuoso database from the ntriple files
########################################################################
function build_database(){

cd ${db_dir}
virtuoso_ini=${db_dir}virtuoso.ini
virtuoso_log="${db_dir}virtuoso.log"
virtuoso_status check
if $check
	then
	echo "INFO: a virtuoso instance (virtuoso-t) is running"
	echo "INFO: Shutting it down now."
	virtuoso_shutdown
fi

echo "INFO: Removing old database files as we are creating a new database now"
rm -f {virtuoso.db,virtuoso-temp.db,virtuoso.pxa,virtuoso.trx,virtuoso.lck} > /dev/null

echo "INFO: Starting virtuoso"
./virtuoso-t +configfile=virtuoso.ini &

# NOTE: There is a fault here when the commented lines are used.
tail -n 0 -F "${virtuoso_log}" | while read LOGLINE
do
	[[ "${LOGLINE}" == *"Server online at 1111"* ]] && echo "INFO: Virtuoso is up and running" && pkill -P $$ tail
    #[[ "${LOGLINE}" == *"Virtuoso is already runnning"* ]] && echo "Virtuoso already running" && pkill -P $$ tail
	#[[ "${LOGLINE}" == *"There is no configuration file virtuoso.ini"* ]] && echo "No virtuoso.ini file found" && pkill -P $$ tail

done

echo "INFO: Loading compressed ntriples in the scripts/ directory recursively"
run_cmd "ld_dir_all('${data_dir}/','*.nt.gz','${SPACE_NAME}')"
run_cmd "ld_dir_all('${data_dir}/','*.nt','${SPACE_NAME}')"
run_cmd "ld_dir_all('${data_dir}/','*.owl','${SPACE_NAME}')"
run_cmd "ld_dir_all('${data_dir}/','*.ttl.gz','${SPACE_NAME}')"
run_cmd "ld_dir_all('${data_dir}/','*.rdf.gz','${SPACE_NAME}')"

# Start rdf loaders to handle the data
echo "INFO: Starting RDF loaders"
for x in {1..3}
do 
 	${isql_cmd} ${isql_pass} verbose=on echo=on errors=stdout banner=off prompt=off exec='rdf_loader_run(); exit;' &> /dev/null &
done

# check the loading process and wait untill it is finished
while true; do
	result=`./isql localhost:1111 -U dba -P dba banner=off verbose=off exec="select count(1) from load_list where ll_state=0 or ll_state=1;"`

	if [ "$result" == 0 ]; then
		echo "INFO: Finished loading"
		break
	fi
	echo -en "\rstill waiting...files left: $result"
	sleep 300
done

 echo "INFO: Shutdown virtuoso now"
 virtuoso_shutdown

}

###############################################################################
#	Generate the hadoop analytics and load into virtuoso
##############################################################################
function generate_analytics(){
	echo "INFO: Generating analytics"

	WORKDIR=/home/dankla/analytics/graphsummary
	CLASS_PATH=$WORKDIR/scripts/hadoop-summary-0.0.14-assembly.jar
	HADOOP_BIN=/home/dankla/analytics/hadoop/bin/hadoop

	HADOOP_STATS_DIR=${data_dir}/analytics_$(date +"%Y-%m-%d")_$(date +"%H-%M-%S")
	EXPORT_DIR=${data_dir}

	if [ ! -d "$HADOOP_STATS_DIR" ]; then
		mkdir "$HADOOP_STATS_DIR"
		chown dankla:dankla "$HADOOP_STATS_DIR"
	fi

	# take the latest sindice-export
	# change date to name of folder you want to put analysis in that is inside export dir
	DATE=$(date +"%Y-%m-%d")
	RUN_ID=$(hostname -s)_$(date +"%H-%M-%S")
	HDFS_BASE_PATH="/user/dankla/bio2rdf-dataspaces"
	HDFS_RUN_PATH=${HDFS_BASE_PATH}/${DATE}_$RUN_ID
	HDFS_FILTER_PATH=${HDFS_BASE_PATH}/${DATE}_${RUN_ID}_filtered
	
	echo "INFO: WORKDIR is being set to absolute reference: $WORKDIR"
	echo "INFO: Creating input/ and output/ in $HDFS_RUN_PATH"
	
	sudo -u dankla $HADOOP_BIN fs -mkdir $HDFS_RUN_PATH/output
	sudo -u dankla $HADOOP_BIN fs -mkdir $HDFS_RUN_PATH/input

	# File which as a flag purpose: to indicate when the process has finished
	sudo -u dankla $HADOOP_BIN fs -touchz $HDFS_RUN_PATH/load.disable

	# Upload the data to HDFS
	for f in $(find $EXPORT_DIR -name "*.nt.gz" -or -name '*.nt');
	do
		echo "INFO: Uploading from $f to $HDFS_RUN_PATH."
		sudo -u dankla $HADOOP_BIN fs -put $f $HDFS_RUN_PATH/input
	done

	echo "INFO: Upload complete."

	#Data Graph Summary Cascade
	sudo -u dankla $HADOOP_BIN jar $CLASS_PATH org.sindice.graphsummary.cascading.DataGraphSummaryCascadeCLI --input $HDFS_RUN_PATH/input --output $HDFS_RUN_PATH/output --cascade-config $WORKDIR/scripts/config.yaml --input-format TEXTLINE --date $DATE
	
	if [ $? -eq 1 ]; then
    	echo "ERROR:Error while computing the summary" 
    	exit 1
	fi

	# Data Node Filter Cascade
	sudo -u dankla $HADOOP_BIN fs -mkdir $HDFS_FILTER_PATH
	sudo -u dankla $HADOOP_BIN jar $CLASS_PATH org.sindice.graphsummary.cascading.rdf.filter.NodeFilterSummaryGraphCLI --input $HDFS_RUN_PATH/output/rdf-dumps --output $HDFS_FILTER_PATH/ --cascade-config $WORKDIR/scripts/config.yaml --input-format TEXTLINE --filter-query $root_dir/filters/cardinality_1.txt

	if [ $? -eq 0 ]; then
    	sudo -u dankla $HADOOP_BIN fs -get " $HDFS_FILTER_PATH/part*" $HADOOP_STATS_DIR/
    else
    	echo "ERROR:Error while computing the summary" 
    	exit 1
	fi
	
	# merge the files into a single compressed nq file
	cd "$HADOOP_STATS_DIR"
	if [ -f "${SPACE_NAME}.nq.gz" ];
		then
		rm "${SPACE_NAME}.nq.gz"
	fi

	touch ${SPACE_NAME}.nq
	zcat *.nq.gz > ${SPACE_NAME}.nq
	gzip ${SPACE_NAME}.nq

	rm part*

 ##
 # Load the analytics file into the virtuoso db
cd "${db_dir}"

virtuoso_status check
if $check
	then
	echo "INFO: a virtuoso instance (virtuoso-t) is running"
	echo "INFO: Shutting it down now."
	virtuoso_shutdown
fi

echo "INFO: Starting virtuoso"
`./virtuoso-t &`

log="$(pwd)/virtuoso.log"

tail -n 0 -F "${log}" | while read LOGLINE
do
	[[ "${LOGLINE}" == *"Server online at 1111"* ]] && pkill -P $$ tail
done

echo "INFO: Virtuoso is up and running"
echo "INFO: Loading compressed nquads in the scripts/ directory recursively"
run_cmd "ld_dir('${$HADOOP_STATS_DIR}','*.nq.gz','analytics_is_nquads')"
run_cmd "rdf_loader_run()"

echo "INFO: Shutdown virtuoso now"
virtuoso_shutdown
}

##
# add the data created to the solr index 
function index(){
	find /opt/data/${SPACE_NAME}/ -name "*.nt.gz" -print | xargs java -jar ${root_dir}/bin/obc-solrloader.jar -dataspace ${SPACE_NAME} -solr ${SOLR} -file
}

##
# Package all the data, virtuoso.db, and analytics in a tar ball ready for export.
function package(){
	cd ${data_dir}
	deploy="/opt/dataspaces/"
	mkdir -p $deploy
	cd ${data_dir} && mv virtuoso ${SPACE_NAME} && tar -cvzf ${SPACE_NAME}.tar.gz ${SPACE_NAME}/ && mv ${SPACE_NAME}.tar.gz $deploy
}

##
# Send an email when everything is finished
function alert(){
	echo "Finished processing ${SPACE_NAME}" | mail dataspace $1
}
