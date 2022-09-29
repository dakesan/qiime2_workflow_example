#!/bin/bash

qiime dada2 denoise-single \
--p-trim-left 13 \
--p-trunc-len 150 \
--i-demultiplexed-seqs q2_core_data/sequence/demux.qza \
--o-representative-sequences q2_core_data/sequence/rep_seq.qza \
--o-table q2_core_data/feature/feature_table.qza \
--o-denoising-stats q2_core_data/feature/denoise_stats.qza \
--p-n-threads 4
