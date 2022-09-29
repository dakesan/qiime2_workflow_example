#!/bin/bash

mkdir -p visualize/demux

qiime demux summarize \
--i-data ./q2_core_data/sequence/demux.qza \
--o-visualization ./visualize/demux/demux.qzv

qiime tools export \
--input-path ./visualize/demux/demux.qzv \
--output-path ./visualize/demux