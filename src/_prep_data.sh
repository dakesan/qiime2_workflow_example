#!/bin/bash

mkdir -p prep_data
mkdir emp

curl -sL \
"https://data.qiime2.org/2022.8/tutorials/atacama-soils/sample_metadata.tsv" > \
"prep_data/metadata.tsv"

curl -sL \
"https://data.qiime2.org/2022.8/tutorials/atacama-soils/10p/forward.fastq.gz" > \
"emp/forward.fastq.gz"

curl -sL \
"https://data.qiime2.org/2022.8/tutorials/atacama-soils/10p/reverse.fastq.gz" > \
"emp/reverse.fastq.gz"

curl -sL \
"https://data.qiime2.org/2022.8/tutorials/atacama-soils/10p/barcodes.fastq.gz" > \
"emp/barcodes.fastq.gz"