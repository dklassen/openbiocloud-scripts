#! /bin/bash

isql="${root_dir}/virtuoso/bin/isql"
isql_cmd="${isql} localhost:1111 -U dba"
isql_pass='-P dba'

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
		wget https://github.com/micheldumontier/php-lib/archive/master.zip -O rdfapi.zip
		unzip rdfapi.zip && rm rdfapi.zip
		mv php-lib-master/ php-lib/
		cd previous
	fi

	folder="${scripts}/${1}"
	echo "INFO: Creating folder: ${folder}"
	mkdir -p $folder

	if [ -f "${folder}/$1.php" ]; then
		rm "${folder}/$1.php"
	fi

	cd $folder
	echo "INFO: Downloading from github ${2} to ${1}.php"
	wget --no-check-certificate -q "${2}" "${1}.php"

	if [ ! -d "./download" ]; then 
		mkdir "./download"
	fi

	if [ ! -d "./data" ] ;then 
		mkdir "./data"
	fi

	if [ "$3" == "" ];then
		php "${1}.php" files=all indir="$(pwd)/download/" outdir="$(pwd)/data/"
	else
		echo "INFO: Running with files flag set to $3"
		php "${1}.php" files=${3} indir="$(pwd)/download/" outdir="$(pwd)/data/" $4
	fi

	status=$?
    if [ $status -ne 0 ]; then
        echo "ERROR: Current scripted ${1} died"
    fi

}
##########################################################################
# run the passed in command through the virtuoso isql interface
# params : isql command
##########################################################################
function run_cmd(){

echo "INFO: Running virtuoso command: $1"
#tail -n0 -F $logfile 2>/dev/null | trigger $! &

${isql_cmd} ${isql_pass} <<EOF &> $logfile
	$1;
	exit;
EOF

}

##########################################################################
# start new rdf_loader as background job
##########################################################################
function rdf_loader_run(){
echo  ${isql_cmd} ${isql_pass} verbose=on echo=on errors=stdout banner=off prompt=off exec="rdf_loader_run(); exit;" &> /dev/null &
   `${isql_cmd} ${isql_pass} verbose=on echo=on errors=stdout banner=off prompt=off exec="rdf_loader_run(); exit;" &> /dev/null &`
}

###########################################################################
# Shutdown a virtuoso instance
###########################################################################
function virtuoso_shutdown(){
	while true ; do
		#virtuoso_pid=$(ps aux | grep -v grep | grep virtuoso-t | awk '{print $2}')
		virtuoso_pid=$(ps -e | grep virtuoso-t | awk '{print $1}')
		
		kill -9 "$virtuoso_pid"

		virtuoso_pid=$(ps -e | grep virtuoso-t | awk '{print $1}')
		if [ "$virtuoso_pid" != "" ] ;
		then
			echo "INFO: Virtuoso is shutdown"
			break
		fi
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

cd "${root_dir}/virtuoso/bin/"
virtuoso_ini="../var/lib/virtuoso/db/virtuoso.ini"

virtuoso_status check
if $check
	then
	echo "INFO: a virtuoso instance (virtuoso-t) is running"
	echo "INFO: Shutting it down now."

	virtuoso_shutdown
fi

echo "INFO: Removing old database files as we are creating a new database now"
rm {virtuoso.db,virtuoso-temp.db,virtuoso.pxa,virtuoso.trx,virtuoso.lck,virtuoso.log} > /dev/null

echo "INFO: Starting virtuoso"
`./virtuoso-t &`

log="$(pwd)/virtuoso.log"

tail -n 0 -F "${log}" | while read LOGLINE
do
	[[ "${LOGLINE}" == *"Server online at 1111"* ]] && pkill -P $$ tail
	[[ "${LOGLINE}" == *"Virtuoso is already runnning"* ]] && echo "Virtuoso already running" && pkill -P $$ tail
	[[ "${LOGLINE}" == *"There is no configuration file virtuoso.ini"* ]] && echo "No virtuoso.ini file found" && pkill -P $$ tail
done

echo "INFO: Virtuoso is up and running"

echo "INFO: Loading compressed ntriples in the scripts/ directory recursively"
run_cmd "ld_dir_all('${scripts}/','*.nt.gz','${SPACE_NAME}')"
run_cmd "ld_dir_all('${scripts}/','*.nt','${SPACE_NAME}')"
run_cmd "ld_dir_all('${scripts}/','*.owl','${SPACE_NAME}')"
run_cmd "ld_dir_all('${scripts}/','*.ttl.gz','${SPACE_NAME}')"

# start five rdf loaders to handle the data
echo "INFO: Starting RDF loaders"
for x in {1..5}
do 
 	rdf_loader_run 
done

# check the loading process and wait untill it is finished
while true; do
	result=`./isql localhost:1111 -U dba -P dba banner=off verbose=off exec="select count(1) from load_list where ll_state=0 or ll_state=1;"`

	if [ "$result" == 0 ]; then
		echo "INFO: Finished loading"
		break
	fi
	echo -en "\rstill waiting...files left: $result"
	sleep 2
done


echo "INFO: Shutdown virtuoso now"
virtuoso_shutdown

}

###############################################################################
#	Generate the hadoop analytics and load into virtuoso
##############################################################################
function generate_analytics(){
	echo "INFO: Generating analytics"

	WORKDIR=/home/dankla/bio2rdf-dataspaces/analytics/graph_analytics
	CLASS_PATH=$WORKDIR/scripts/analytics-assembly.jar
	HADOOP_BIN=/home/dankla/bio2rdf-dataspaces/analytics/hadoop/bin/hadoop

	mkdir "$root_dir/analytics"
	HADOOP_STATS_DIR=${root_dir}/analytics
	EXPORT_DIR=${scripts}

	# take the latest sindice-export
	# change date to name of folder you want to put analysis in that is inside export dir
	DATE=$(date +"%Y-%m-%d")
	RUN_ID=$(hostname -s)_$(date +"%H-%M-%S")
	HDFS_BASE_PATH="/user/dankla/bio2rdf-dataspaces"
	HDFS_RUN_PATH=${HDFS_BASE_PATH}/${DATE}_$RUN_ID
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

	# Data Graph Summary Cascade
	sudo -u dankla $HADOOP_BIN jar $CLASS_PATH org.sindice.graphsummary.cascading.DataGraphSummaryCascadeCLI --input $HDFS_RUN_PATH/input --output $HDFS_RUN_PATH/output --cascade-config $WORKDIR/scripts/config.yaml --input-format TEXTLINE --date $DATE
	
	if [ $? -eq 0 ]; then
		sudo -u dankla $HADOOP_BIN fs -get "$HDFS_RUN_PATH/output/rdf-dumps/*" $HADOOP_STATS_DIR/
		sudo -u dankla $HADOOP_BIN fs -mv "$HDFS_RUN_PATH/output/rdf-dumps/*" $HDFS_RUN_PATH/
		sudo -u dankla $HADOOP_BIN fs -rmr $HDFS_RUN_PATH/output/rdf-dumps/

    	# Allow the virtuoso script to load the dumps
    	sudo -u dankla $HADOOP_BIN fs -rm $HDFS_RUN_PATH/load.disable
	else
    	echo "Error while computing the summary"
    	exit 1
	fi

	# merge the files into a single compressed nq file
	cd "$root_dir/analytics"
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
cd "${root_dir}/virtuoso/bin/"

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
	[[ "${LOGLINE}" == *"Virtuoso is already runnning"* ]] && echo "Virtuoso already running" && pkill -P $$ tail
	[[ "${LOGLINE}" == *"There is no configuration file virtuoso.ini"* ]] && echo "No virtuoso.ini file found" && pkill -P $$ tail
done

echo "INFO: Virtuoso is up and running"

echo "INFO: Loading compressed nquads in the scripts/ directory recursively"
run_cmd "ld_dir('${root_dir}/analytics/','*.nq.gz','analytics_is_nquads')"
run_cmd "rdf_loader_run()"

echo "INFO: Shutdown virtuoso now"
virtuoso_shutdown
}

##
# Package all the data, virtuoso.db, and analytics in a tar ball ready for export.
function package(){
	cd ${root_dir}
	deploy="${scripts}/deploy"
	mkdir $deploy
	mv ${root_dir}/virtuoso/bin/virtuoso.db ${deploy}
	mv ${root_dir}/analytics/${SPACE_NAME}.nq.gz ${deploy}/${SPACE_NAME}_analytics.nq.gz
	tar -cvzf ${scripts}/${SPACE_NAME}.tar.gz ${deploy}
}

##
# Send an email when everything is finished
function alert(){
	echo "Finished processing ${SPACE_NAME}" | mail dataspace $1
}