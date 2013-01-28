#! /bin/bash
source ./functions.sh

SPACE_NAME="drugspace"
root_dir="$(pwd)"
scripts="${root_dir}/scripts"

sources[0]="ndc https://raw.github.com/bio2rdf/bio2rdf-scripts/master/ndc/ndc.php"
sources[1]="omim https://raw.github.com/dklassen/bio2rdf-scripts/master/omim/omim.php"
sources[2]="drugbank https://raw.github.com/dklassen/bio2rdf-scripts/master/drugbank/drugbank.php"
sources[3]="sider https://raw.github.com/micheldumontier/bio2rdf-scripts/sider/sider/sider.php"

#=========================================================================
# Start the script here
#=========================================================================
generate_data 
build_database
generate_analytics
package
alert $1



