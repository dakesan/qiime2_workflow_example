#!/bin/bash

qiime phylogeny align-to-tree-mafft-fasttree \
--i-sequences q2_core_data/sequence/rep_seq.qza \
--o-alignment q2_core_data/sequence/aligned_rep_seq.qza \
--o-masked-alignment q2_core_data/sequence/masked_aligned_rep_seq.qza \
--o-tree q2_core_data/taxonomy/unrooted_tree.qza \
--o-rooted-tree q2_core_data/taxonomy/rooted_tree.qza

rm -r ./statistics/core_metrics

qiime diversity core-metrics-phylogenetic \
--i-phylogeny q2_core_data/taxonomy/rooted_tree.qza \
--i-table q2_core_data/feature/feature_table.qza \
--p-sampling-depth 1103 \
--m-metadata-file prep_data/metadata.tsv \
--output-dir statistics/core_metrics

mv statistics/core_metrics/bray* statistics/beta_diversity/
mv statistics/core_metrics/jaccard* statistics/beta_diversity/
mv statistics/core_metrics/*vector.qza statistics/alpha_diversity/

