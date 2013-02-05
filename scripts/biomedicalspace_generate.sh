#! /bin/bash
source ./functions.sh

#- CTD ( genes, drugs, diseases - associations) MESH, OMIM, pubmed
#- PharmGKB (genes, drugs, diseases, snps, drug-disease associations, drug-gene associations, drug-drug interactions, drug-target interactions)
#- ChEMBL (bioassay)
#- PubMED
#- MGI, RGD, SGD, WormBase, FlyBase
#- dbSNP

SPACE_NAME="biomedicalspace"
root_dir="$(pwd)"
scripts="${root_dir}/${SPACE_NAME}"

source ./functions.sh

mkdir $scripts

sources[0]="ctd https://raw.github.com/bio2rdf/bio2rdf-scripts/master/ctd/ctd.php"
sources[1]="pharmgkb https://github.com/bio2rdf/bio2rdf-scripts/raw/master/pharmgkb/pharmgkb.php"
sources[2]="pubchem https://raw.github.com/bio2rdf/bio2rdf-scripts/master/pubchem/pubchem.php bioactivities"
sources[3]='mgi https://raw.github.com/bio2rdf/bio2rdf-scripts/master/mgi/mgi.php'
# Going to have to be custom as it requires the data to be downloaded already
sources[2]="pubmed https://raw.github.com/bio2rdf/bio2rdf-scripts/master/pubmed/pubmed.php"
