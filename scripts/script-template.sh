#! /bin/bash
set -e 
unmask 0022

SPACE_NAME="set space name here"
data_dir="where the generated data will be stored"
db_dir="where virtuoso db will be generated"

root_dir=$(dirname $(dirname "$(pwd)/.."))
scripts="${root_dir}/dataspaces/${SPACE_NAME}"
logfile="${data_dir}/${SPACE_NAME}_$(date +"%Y-%m-%d").log"


#
# Print the HELP message
function help(){
cat <<HELP
    Format : -flags action

    the following flags can be used
        -c  clear the load_list prior to data running virtuoso
    the following actions can be specified
        build:  build the database
        generate:   Generate the data
        analytics:  Calculate analytics over existing data
        create:     Create the database. Generate data, build database, and calculate analytics
        reset:      Clears all the data and script directories !
HELP
}

cd $root_dir
source ./lib/functions.sh
source ./lib/common.sh

check_virtuoso_install
setup_data_dir
touch $logfile
if [ ! -d "$scripts" ]; then
    mkdir -p $scripts
fi

if [ $# == 0 ];then
 echo help
 exit 1
fi

OPTIND=1
while getopts "hc" opt: do
    case $opt in
        h)
            echo help
            exit 0
        ;;
         c)
             clear_load_list=0
        ;;
    esac
done

shift $(($OPTIND -1 ))

case $1
    build)
    ;;
    generate)
    ;;
    create)
    ;;
    restart)
    ;;
    analytics)
    ;;
esac
