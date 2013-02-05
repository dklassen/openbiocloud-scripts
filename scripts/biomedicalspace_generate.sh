#! /bin/bash

#- CTD ( genes, drugs, diseases - associations) MESH, OMIM, pubmed
#- PharmGKB (genes, drugs, diseases, snps, drug-disease associations, drug-gene associations, drug-drug interactions, drug-target interactions)
#- ChEMBL (bioassay)
#- PubMED
#- MGI, RGD, SGD, WormBase, FlyBase
#- dbSNP

#! /bin/bash

SPACE_NAME="biomedical_space"

root_dir=$(dirname $(dirname "$(pwd)/.."))
scripts="${root_dir}/dataspaces/${SPACE_NAME}"
logfile="/tmp/${SPACE_NAME}_$(date +"%Y-%m-%d").log"

touch $logfile

cd $root_dir
source ./lib/functions.sh

# Start fresh
 rm -rf $scripts

# Directory where we are going to put everything
if [ ! -d "$scripts" ];then
	mkdir -p $scripts
fi

# sources[0]="ctd https://raw.github.com/bio2rdf/bio2rdf-scripts/master/ctd/ctd.php"
 sources[1]="pharmgkb https://github.com/bio2rdf/bio2rdf-scripts/raw/master/pharmgkb/pharmgkb.php offsides"
#sources[0]="pubchem https://raw.github.com/dklassen/bio2rdf-scripts/pubchem/pubchem/pubchem.php bioactivity sync=true"
# sources[3]='mgi https://raw.github.com/bio2rdf/bio2rdf-scripts/master/mgi/mgi.php'

# # Direct download from bio2rdf server
# pubmed="http://download.bio2rdf.org/release/2/pubmed/"
# mkdir ${scripts}/pubmed || cd $_
# wget -r -nH -np ${pubmed}
# find ./release -name '*.nt.gz' -exec cp {} ./ \;
# rm -rf release/

#=========================================================================
# Start the bio2rdf scripts here
#=========================================================================

# pubmed script requires we make specific subdirectories which we can specfiy through the setup

#mkdir -p "${root_dir}/dataspaces/${SPACE_NAME}/pubchem/download/{bioactivity compounds substances}"

generate_data
build_database
#generate_analytics
package
alert $1