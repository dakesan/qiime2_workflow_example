#!/bin/bash

CLASSIFIER="gg-13-8-99-515-806-nb-classifier.qza"

qiime feature-classifier classify-sklearn \
--i-classifier $CLASSIFIER \
--i-reads q2_core_data/sequence/rep_seq.qza \
--o-classification q2_core_data/taxonomy/taxonomy.qza

qiime metadata tabulate \
--m-input-file q2_core_data/taxonomy/taxonomy.qza \
--o-visualization q2_core_data/taxonomy/taxonomy.qzv

qiime tools export \
--input-path q2_core_data/taxonomy/taxonomy.qzv \
--output-path visualization/taxonomy

qiime taxa barplot \
--i-table q2_core_data/feature/feature_table.qza \
--i-taxonomy q2_core_data/taxonomy/taxonomy.qza \
--m-metadata-file prep_data/metadata.tsv \
--o-visualization visualization/bar_plot
