#!bash

mkdir -p prep_data/fastq_input
mkdir -p q2_core_data/sequence

qiime tools import \
--type EMPPairedEndSequences \
--input-path emp \
--output-path ./prep_data/fastq_input/fastq.qza

qiime demux emp-paired \
--m-barcodes-file prep_data/metadata.tsv \
--m-barcodes-column barcode-sequence \
--p-rev-comp-mapping-barcodes \
--i-seqs ./prep_data/fastq_input/fastq.qza \
--o-per-sample-sequences ./q2_core_data/sequence/demux.qza \
--o-error-correction-details ./q2_core_data/sequence/demux_details.qza
