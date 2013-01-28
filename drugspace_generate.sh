#! /bin/bash
source ./functions.sh

SPACE_NAME="drugspace"
root_dir="$(pwd)"
scripts="${root_dir}/scripts"

ndc_script="https://raw.github.com/bio2rdf/bio2rdf-scripts/master/ndc/ndc.php"
omim_script="https://raw.github.com/dklassen/bio2rdf-scripts/master/omim/omim.php"
drugbank_script="https://raw.github.com/dklassen/bio2rdf-scripts/master/drugbank/drugbank.php"
sider_script="https://raw.github.com/micheldumontier/bio2rdf-scripts/sider/sider/sider.php"

declare -a sources=("ndc\t$ndc_script" "omim\t$omim_script" "drugbank\t$drugbank_script" "sider\t$sider_script")

#=========================================================================
# Start the script here
#=========================================================================
generate_data $sources
build_database
generate_analytics
package
alert $1



