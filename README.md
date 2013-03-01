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


Running Tips and Tricks
========================

[27/02/2013 11:33:32] Campinas Stéphane: hadoop jar target/hadoop-summary-0.0.14-SNAPSHOT-assembly.jar org.sindice.graphsummary.cascading.rdf.filter.NodeFilterSummaryGraphCLI --input dana/summary --output dana/summary_filtered --input-format TEXTLINE --filter-query ./query
[27/02/2013 11:33:54] Campinas Stéphane: 

Example text in filter text file

> ?node <http://vocab.sindice.net/domain_uri> ?d ;
>      <http://vocab.sindice.net/analytics#cardinality> ?card .
> FILTER(?card = 1)