OpenBioCloud-Scripts
====================

This repo is a collection of bash build scripts used to create a virtuoso db
from a set of bio2rdf scripts, generate, and load analytics graph.

The dataspaces that are generated are:

drugspace
biomolspace
rnaspace
yeastspace

Generating data usings a common folder pattern

> /opt/data/${SPACENAME}/${DATASOURCE}/{data,download}
This is the directory where the data is downloaded and processed any valid rdf here will be loaded into virtuoso

> /opt/dataspaces/${SPACENAME}.tar.gz
This is the directory where the tarball is placed after processing

Requirements
===========

raptor-utils
hadoop analytics (specific to scripts)
mysql
