me2-2020.11版

笹井さん・渡邊さんが作ってくださっている標準スクリプトの移植記事です。

## バージョン情報

- QIIME2（2020.11版）
- SILVA_138_1_SSURef_NR99_tax_silva(99%でクラスタリングされたデータベース)、
- NCBI 16S RefSeq records [BioProject ID: 33175 & 33317] (2019年12月18日ダウンロード)

## 解析の準備

①　サーバー接続前日にウイルスバスターで自身PC全体をチェックする
　　　　→　ウイルス定義ファイルを更新するためにシャットダウンを日々実施する
②　解析用のファイルを準備する
　　　　→　Read1, Read2, IndexのfastqファイルとMapファイルを準備する
　　　　→　ファイル名をforward.fastq.gz , reverse.fastq.gz , barcodes.fastq.gz に変更する（解凍不要）
　　　　→　MapファイルはMap.txtとする
③　自身PCでputty、winSCPを起動し、Linuxサーバーへ接続する
以降、コマンド操作（puttyを使用）、およびファイル転送（winSCP）を行う

サーバーにワーキングディレクトリを作成し、移動およびファイルを転送する

## TOC

@[toc]

## 作業概要

### サーバーにワーキングディレクトリを作成し、移動およびファイルを転送する

#### ワーキングディテクトリを作成

```bash
mkdir WorkingDirectory
# 名前は任意
```

#### ワーキングディレクトリに移動

```bash
cd WorkingDirectory
```

#### ワーキングディレクトリに解析用ファイルを転送

WinSCPにて実施（自身PC→Linuxサーバー）

### Qiime2解析環境作成

#### Qiime2環境起動用コマンド(activate)のPATHを通す

```bash
export PATH="/work1/tools7/miniconda3/bin:$PATH"
```

#### Qiime2環境の起動

```bash
conda activate qiime2-2020.11
```

#### 処理に必要なディレクトリの作成

```bash
mkdir {Log,Error,fastqgz,visualizations,vsearch}
mkdir visualizations/{alpha_diversity,beta_diversity}
```

#### 生リードファイルの移動

```bash
mv ./*.gz fastqgz
```

### Qiime2の実行コマンド1(～Demultiplex)→ demux.qzvを可視化してトリミング領域を決定

```bash
# Import
bsub -J job1 -o Log/Job01.txt -e Error/Job01.txt \
qiime tools import \
--type EMPPairedEndSequences \
--input-path fastqgz \
--output-path fastqgz.qza
#（注意）
# 逆順のバーコードにコントロールする場合あり(`--p-rev-comp-mapM_INg-barcodes`オプションの付与)
# `--o-error-correction-details`の指定が必須となった

# 被験者ごとにリードを振り分けるDemultiplex
bsub -J job2 -w "ended(job1)" -o Log/Job02.txt -e Error/Job02.txt qiime demux emp-paired \
--m-barcodes-file Map.txt \
--m-barcodes-column BarcodeSequence \
--i-seqs fastqgz.qza \
--o-per-sample-sequences demux.qza \
--o-error-correction-details barcode_error_correct.qza

# Demultiplex結果の可視化
bsub -J job3 -w "ended(job2)" -o Log/Job03.txt -e Error/Job03.txt \
qiime demux summarize \
--i-data demux.qza \
--o-visualization demux.qzv

bsub -J job3vis -w "ended(job3)" -o Log/Job03vis.txt -e Error/Job03vis.txt \
qiime tools export \
--input-path demux.qzv \
--output-path visualizations/demux_summary
```

### QIIME2の実行コマンド2(～Phylogeny)

```bash
# Dada2: ノイズ除去、キメラ除去、phiX除去、3'末端トリミング
## パラメーターはdemux summarizeの結果を見て調整の余地あり
## 複数Miseqラン由来サンプルを混ぜて解析する場合はオプション変更　(`--p-pooling-method independent`)
bsub -J job4 -w "ended(job3)" -o Log/Job04.txt -e Error/Job04.txt \
-n 16 qiime dada2 denoise-paired \
--i-demultiplexed-seqs demux.qza \
--o-table table \
--o-representative-sequences rep-seqs \
--p-trim-left-f 20 \
--p-trim-left-r 17 \
--p-trunc-len-f 220 \
--p-trunc-len-r 200 \
--p-n-threads 16 \
--output-dir dada2out \
--p-pooling-method pseudo

# Dada2結果の可視化
bsub -J job5 -w "ended(job4)" -o Log/Job05.txt -e Error/Job05.txt \
qiime metadata tabulate \
--m-input-file dada2out/denoising_stats.qza \
--o-visualization dada2out/denoising_stats.qzv

# feature tableの概要
bsub -J job6 -w "ended(job4)" -o Log/Job06.txt -e Error/Job06.txt qiime \
feature-table summarize \
--i-table table.qza \
--o-visualization table.qzv \
--m-sample-metadata-file Map.txt

# 代表配列のエクスポート
bsub -J job7 -w "ended(job4)" -o Log/Job07.txt -e Error/Job07.txt \
qiime tools export \
--input-path rep-seqs.qza \
--output-path rep_seq

# Feature tableをbiom形式に変換
bsub -J job8a -w "ended(job4)" -o Log/Job08a.txt -e Error/Job08a.txt \
qiime tools export \
--input-path table.qza \
--output-path table_biom
# biomファイルをtxtに変換
bsub -J job8b -w "ended(job8a)" -o Log/Job08b.txt -e Error/Job08b.txt \
biom convert \
-i table_biom/feature-table.biom \
-o table_biom/feature-table.txt --to-tsv

# Feature tableを相対値データに変換\
bsub -J job8c -w "ended(job4)" -o Log/Job08c.txt -e Error/Job08c.txt \
qiime feature-table relative-frequency \
--i-table table.qza \
--o-relative-frequency-table relative_table.qza

# 相対Feature tableをbiom形式に変換
bsub -J job8d -w "ended(job8c)" -o Log/Job08d.txt -e Error/Job08d.txt \
qiime tools export --input-path relative_table.qza \
--output-path relative_table_biom

# 相対biomファイルをtxtに変換
bsub -J job8e -w "ended(job8d)" -o Log/Job08e.txt -e Error/Job08e.txt \
biom convert \
-i relative_table_biom/feature-table.biom \
-o relative_table_biom/feature-table.txt \
--to-tsv

# 系統アサイン
# # 学習済のclassifierは以下から選択。
# # - Silva138.1 V1/V2  "classifier_silva138_1_v12_2020.11.qza"
# # - Silva138.1 V4 "classifier_silva138_1_v4_2020.11.qza"
# # - Silva138 V1/V2"classifier_silva138_v12_2020.11.qza"
# # - Silva138 V4   "classifier_silva138_v4_2020.11.qza"
# Silva 138.1の[update note](https://www.arb-silva.de/documentation/release-1381/)を必ず確認して欲しいですが、基本的には最新版を使うことを推奨します。
CLASSIFIER_PATH="/misc/work1/share/whole/qiime2/2020.11/classifier_silva138_1_v12_2020.11.qza"

bsub -J job9 -w "ended(job4)" -o Log/Job09.txt -e Error/Job09.txt -n 4 \
qiime feature-classifier classify-sklearn \
--i-classifier  $CLASSIFIER_PATH\
--i-reads rep-seqs.qza --o-classification taxonomy.qza --p-n-jobs 4
# データベース大型化によるメモリ消費量増大に対応するため、使用コア数を16→4に削減

# 系統アサイン結果の視覚化
bsub -J job10 -w "ended(job9)" -o Log/Job10.txt -e Error/Job10.txt \
qiime metadata tabulate \
--m-input-file taxonomy.qza \
--o-visualization taxonomy.qzv
# "unidentified"はSilvaDB中に含まれるが系統は未同定であることを示す


# 積み上げ式棒グラフ化
bsub -J job11 -w "ended(job10)" -o Log/Job11.txt -e Error/Job11.txt \
qiime taxa barplot \
--i-table table.qza \
--i-taxonomy taxonomy.qza \
--m-metadata-file Map.txt \
--o-visualization taxa-bar-plots.qzv

# アライメント
bsub -J job12 -w "ended(job4)" -o Log/Job12.txt -e Error/Job12.txt -n 16 \
qiime alignment mafft \
--i-sequences rep-seqs.qza \
--o-alignment aligned-rep-seqs.qza \
--p-n-threads 16

# アライメントをフィルター
bsub -J job13 -w "ended(job12)" -o Log/Job13.txt -e Error/Job13.txt \
qiime alignment mask \
--i-alignment aligned-rep-seqs.qza \
--o-masked-alignment masked-aligned-rep-seqs.qza

# fasttreeで系統樹作成
# # fasttree
bsub -J job14 -w "ended(job13)" -o Log/Job14.txt -e Error/Job14.txt -n 16 \
qiime phylogeny fasttree \
--i-alignment masked-aligned-rep-seqs.qza \
--o-tree unrooted-tree.qza \
--p-n-threads 16
# # rooting
bsub -J job15 -w "ended(job14)" -o Log/Job15.txt -e Error/Job15.txt \
qiime phylogeny midpoint-root \
--i-tree unrooted-tree.qza \
--o-rooted-tree rooted-tree.qza
```

### QIIME2の実行コマンド3(～最後まで)

**depthを決定して実行コマンド3へ**

#### α,β多様性計算

>**depthはtable.qzvを見て決定→できれば5000リード/sample以上はほしい**

```bash
bsub -J job16 -w "ended(job15)" -o Log/Job16.txt -e Error/Job16.txt -n 1 \
qiime diversity core-metrics-phylogenetic \
--i-phylogeny rooted-tree.qza \
--i-table table.qza \
--p-sampling-depth 5000 \
--m-metadata-file Map.txt \
--p-n-jobs-or-threads 1 \
--output-dir core-metrics-results
# （注意） 16コアだと並列化エラーを起こしやすい

bsub -J job17 -w "ended(job15)" -o Log/Job17.txt -e Error/Job17.txt \
qiime diversity alpha-rarefaction \
--i-table table.qza \
--i-phylogeny rooted-tree.qza \
--p-max-depth 5000 \
--m-metadata-file Map.txt \
--o-visualization alpha-rarefaction.qzv

# Familyレベルでまとめてfeature tableを作る→相対値変換→biom変換→tsv変換
# # Taxa collapse
bsub -J job18a -w "ended(job9)" -o Log/Job18a.txt -e Error/Job18a.txt \
qiime taxa collapse \
--i-table table.qza \
--i-taxonomy taxonomy.qza \
--p-level 5 \
--output-dir family_table

# # Convert into relative abundance
bsub -J job18b -w "ended(job18a)" -o Log/Job18b.txt -e Error/Job18b.txt \
qiime feature-table relative-frequency \
--i-table family_table/collapsed_table.qza \
--o-relative-frequency-table family_table/relative_table

# # Export biom
bsub -J job18c -w "ended(job18b)" -o Log/Job18c.txt -e Error/Job18c.txt \
qiime tools export \
--input-path family_table/relative_table.qza \
--output-path family_table/biom

# # Convert biom into tsv
bsub -J job18d -w "ended(job18c)" -o Log/Job18d.txt -e Error/Job18d.txt \
biom convert \
-i family_table/biom/feature-table.biom \
-o family_table/relative_table.txt \
--to-tsv

# Familyレベルのheatmap
bsub -J job19 -w "ended(job18a)" -o Log/Job19.txt -e Error/Job19.txt \
qiime feature-table heatmap \
--i-table family_table/collapsed_table.qza \
--output-dir heatmap

# 代表配列の相同性Top hitを抽出(vs NCBI)
bsub -J job20 -w "ended(job7)" -o Log/Job20.txt -e Error/Job20.txt \
vsearch --usearch_global rep_seq/dna-sequences.fasta \
--db /misc/work1/share/whole/ncbi/191218NCBI_16Smod.fasta \
--id 0.0 --maxaccepts 1 \
--qmask none \
--userfields query+target+id+qcov+ids+mism+gaps \
--userout vsearch/top1hit.txt \
--alnout vsearch/align.txt \
--query_cov 0.85
# 相同性参照データベース NCBI 16S RefSeq recordsの指定

# 生リードファイルの削除
# # （job1にてqzaファイルへ集約のため）
bsub -J job21 -w "ended(job20)" -o Log/Job21.txt -e Error/Job21.txt \
rm -rf ./fastqgz/
```

### オプション1

```bash
# QIIME2結果の可視化コマンド(export一覧)

# # dada2結果
bsub -J job22 -w "ended(job5)" -o Log/Job22.txt -e Error/Job22.txt \
qiime tools export \
--input-path dada2out/denoising_stats.qzv \
--output-path visualizations/denoise_summary

# # feature table summary
bsub -J job23 -w "ended(job6)" -o Log/Job23.txt -e Error/Job23.txt \
qiime tools export \
--input-path table.qzv \
--output-path visualizations/featuretable_summary

# # 系統アサイン結果
bsub -J job24a -w "ended(job10)" -o Log/Job24a.txt -e Error/Job24a.txt \
qiime tools export \
--input-path taxonomy.qzv \
--output-path visualizations/taxonomy

# # 積み上げ式棒グラフ
bsub -J job24b -w "ended(job11)" -o Log/Job24b.txt -e Error/Job24b.txt \
qiime tools export \
--input-path taxa-bar-plots.qzv \
--output-path visualizations/barplots

# # α多様性
bsub -J job25a -w "ended(job16)" -o Log/Job25a.txt -e Error/Job25a.txt \
qiime diversity alpha-group-significance \
--i-alpha-diversity core-metrics-results/faith_pd_vector.qza \
--m-metadata-file Map.txt \
--o-visualization visualizations/alpha_diversity/faith_pd.qzv

bsub -J job25b -w "ended(job25a)" -o Log/Job25b.txt -e Error/Job25b.txt \
qiime tools export \
--input-path visualizations/alpha_diversity/faith_pd.qzv \
--output-path visualizations/alpha_diversity/faith_pd
bsub -J job25c -w "ended(job16)" -o Log/Job25c.txt -e Error/Job25c.txt \
qiime diversity alpha-group-significance \
--i-alpha-diversity core-metrics-results/evenness_vector.qza \
--m-metadata-file Map.txt \
--o-visualization visualizations/alpha_diversity/evenness.qzv
bsub -J job25d -w "ended(job25c)" -o Log/Job25d.txt -e Error/Job25d.txt \
qiime tools export \
--input-path visualizations/alpha_diversity/evenness.qzv \
--output-path visualizations/alpha_diversity/evenness
bsub -J job25e -w "ended(job16)" -o Log/Job25e.txt -e Error/Job25e.txt \
qiime diversity alpha-group-significance \
--i-alpha-diversity core-metrics-results/observed_features_vector.qza \
--m-metadata-file Map.txt \
--o-visualization visualizations/alpha_diversity/observed_features_vector.qzv
bsub -J job25f -w "ended(job25e)" -o Log/Job25f.txt -e Error/Job25f.txt \
qiime tools export \
--input-path visualizations/alpha_diversity/observed_features_vector.qzv \
--output-path visualizations/alpha_diversity/observed_otus
bsub -J job25g -w "ended(job16)" -o Log/Job25g.txt -e Error/Job25g.txt \
qiime diversity alpha-group-significance \
--i-alpha-diversity core-metrics-results/shannon_vector.qza \
--m-metadata-file Map.txt \
--o-visualization visualizations/alpha_diversity/shannon_vector.qzv
bsub -J job25h -w "ended(job25g)" -o Log/Job25h.txt -e Error/Job25h.txt \
qiime tools export \
--input-path visualizations/alpha_diversity/shannon_vector.qzv \
--output-path visualizations/alpha_diversity/shannon

# # β多様性
bsub -J job26a -w "ended(job16)" -o Log/Job26a.txt -e Error/Job26a.txt \
qiime tools export \
--input-path core-metrics-results/bray_curtis_emperor.qzv \
--output-path visualizations/beta_diversity/bray_curtis
bsub -J job26b -w "ended(job16)" -o Log/Job26b.txt -e Error/Job26b.txt \
qiime tools export \
--input-path core-metrics-results/jaccard_emperor.qzv \
--output-path visualizations/beta_diversity/jaccard
bsub -J job26c -w "ended(job16)" -o Log/Job26c.txt -e Error/Job26c.txt \
qiime tools export \
--input-path core-metrics-results/unweighted_unifrac_emperor.qzv \
--output-path visualizations/beta_diversity/unweighted_unifrac
bsub -J job26d -w "ended(job16)" -o Log/Job26d.txt -e Error/Job26d.txt \
qiime tools export \
--input-path core-metrics-results/weighted_unifrac_emperor.qzv \
--output-path visualizations/beta_diversity/weighted_unifrac

# # alpha-rarefactin plot
bsub -J job27 -w "ended(job17)" -o Log/Job27.txt -e Error/Job27.txt \
qiime tools export \
--input-path alpha-rarefaction.qzv \
--output-path visualizations/alpha-rarefaction_plot

# # heatmap
bsub -J job28 -w "ended(job19)" -o Log/Job28.txt -e Error/Job28.txt \
qiime tools export \
--input-path heatmap/visualization.qzv \
--output-path visualizations/heatmap
```

### オプション2

```bash
# 正常完了ジョブのErrorファイルを削除
find Error/ -empty | xargs rm
```# 標準スクリプト qiime2-2020.11版

笹井さん・渡邊さんが作ってくださっている標準スクリプトの移植記事です。

## バージョン情報

- QIIME2（2020.11版）
- SILVA_138_1_SSURef_NR99_tax_silva(99%でクラスタリングされたデータベース)、
- NCBI 16S RefSeq records [BioProject ID: 33175 & 33317] (2019年12月18日ダウンロード)

## 解析の準備

①　サーバー接続前日にウイルスバスターで自身PC全体をチェックする
　　　　→　ウイルス定義ファイルを更新するためにシャットダウンを日々実施する
②　解析用のファイルを準備する
　　　　→　Read1, Read2, IndexのfastqファイルとMapファイルを準備する
　　　　→　ファイル名をforward.fastq.gz , reverse.fastq.gz , barcodes.fastq.gz に変更する（解凍不要）
　　　　→　MapファイルはMap.txtとする
③　自身PCでputty、winSCPを起動し、Linuxサーバーへ接続する
以降、コマンド操作（puttyを使用）、およびファイル転送（winSCP）を行う

サーバーにワーキングディレクトリを作成し、移動およびファイルを転送する

## TOC

@[toc]

## 作業概要

### サーバーにワーキングディレクトリを作成し、移動およびファイルを転送する

#### ワーキングディテクトリを作成

```bash
mkdir WorkingDirectory
# 名前は任意
```

#### ワーキングディレクトリに移動

```bash
cd WorkingDirectory
```

#### ワーキングディレクトリに解析用ファイルを転送

WinSCPにて実施（自身PC→Linuxサーバー）

### Qiime2解析環境作成

#### Qiime2環境起動用コマンド(activate)のPATHを通す

```bash
export PATH="/work1/tools7/miniconda3/bin:$PATH"
```

#### Qiime2環境の起動

```bash
conda activate qiime2-2020.11
```

#### 処理に必要なディレクトリの作成

```bash
mkdir {Log,Error,fastqgz,visualizations,vsearch}
mkdir visualizations/{alpha_diversity,beta_diversity}
```

#### 生リードファイルの移動

```bash
mv ./*.gz fastqgz
```

### Qiime2の実行コマンド1(～Demultiplex)→ demux.qzvを可視化してトリミング領域を決定

```bash
# Import
bsub -J job1 -o Log/Job01.txt -e Error/Job01.txt \
	qiime tools import \
	--type EMPPairedEndSequences \
	--input-path fastqgz \
	--output-path fastqgz.qza
#（注意）
# 逆順のバーコードにコントロールする場合あり(`--p-rev-comp-mapM_INg-barcodes`オプションの付与)
# `--o-error-correction-details`の指定が必須となった

# 被験者ごとにリードを振り分けるDemultiplex
bsub -J job2 -w "ended(job1)" -o Log/Job02.txt -e Error/Job02.txt qiime demux emp-paired \
	--m-barcodes-file Map.txt \
	--m-barcodes-column BarcodeSequence \
	--i-seqs fastqgz.qza \
	--o-per-sample-sequences demux.qza \
	--o-error-correction-details barcode_error_correct.qza

# Demultiplex結果の可視化
bsub -J job3 -w "ended(job2)" -o Log/Job03.txt -e Error/Job03.txt \
	qiime demux summarize \
	--i-data demux.qza \
	--o-visualization demux.qzv

bsub -J job3vis -w "ended(job3)" -o Log/Job03vis.txt -e Error/Job03vis.txt \
	qiime tools export \
	--input-path demux.qzv \
	--output-path visualizations/demux_summary
```

### QIIME2の実行コマンド2(～Phylogeny)

```bash
# Dada2: ノイズ除去、キメラ除去、phiX除去、3'末端トリミング
## パラメーターはdemux summarizeの結果を見て調整の余地あり
## 複数Miseqラン由来サンプルを混ぜて解析する場合はオプション変更　(`--p-pooling-method independent`)
bsub -J job4 -w "ended(job3)" -o Log/Job04.txt -e Error/Job04.txt \
	-n 16 qiime dada2 denoise-paired \
	--i-demultiplexed-seqs demux.qza \
	--o-table table \
	--o-representative-sequences rep-seqs \
	--p-trim-left-f 20 \
	--p-trim-left-r 17 \
	--p-trunc-len-f 220 \
	--p-trunc-len-r 200 \
	--p-n-threads 16 \
	--output-dir dada2out \
	--p-pooling-method pseudo

# Dada2結果の可視化
bsub -J job5 -w "ended(job4)" -o Log/Job05.txt -e Error/Job05.txt \
	qiime metadata tabulate \
	--m-input-file dada2out/denoising_stats.qza \
	--o-visualization dada2out/denoising_stats.qzv

# feature tableの概要
bsub -J job6 -w "ended(job4)" -o Log/Job06.txt -e Error/Job06.txt qiime \
	feature-table summarize \
	--i-table table.qza \
	--o-visualization table.qzv \
	--m-sample-metadata-file Map.txt

# 代表配列のエクスポート
bsub -J job7 -w "ended(job4)" -o Log/Job07.txt -e Error/Job07.txt \
	qiime tools export \
	--input-path rep-seqs.qza \
	--output-path rep_seq

# Feature tableをbiom形式に変換
bsub -J job8a -w "ended(job4)" -o Log/Job08a.txt -e Error/Job08a.txt \
	qiime tools export \
	--input-path table.qza \
	--output-path table_biom
# biomファイルをtxtに変換
bsub -J job8b -w "ended(job8a)" -o Log/Job08b.txt -e Error/Job08b.txt \
	biom convert \
	-i table_biom/feature-table.biom \
	-o table_biom/feature-table.txt --to-tsv

# Feature tableを相対値データに変換\
bsub -J job8c -w "ended(job4)" -o Log/Job08c.txt -e Error/Job08c.txt \
	qiime feature-table relative-frequency \
	--i-table table.qza \
	--o-relative-frequency-table relative_table.qza

# 相対Feature tableをbiom形式に変換
bsub -J job8d -w "ended(job8c)" -o Log/Job08d.txt -e Error/Job08d.txt \
	qiime tools export --input-path relative_table.qza \
	--output-path relative_table_biom

# 相対biomファイルをtxtに変換
bsub -J job8e -w "ended(job8d)" -o Log/Job08e.txt -e Error/Job08e.txt \
	biom convert \
	-i relative_table_biom/feature-table.biom \
	-o relative_table_biom/feature-table.txt \
	--to-tsv

# 系統アサイン
# # 学習済のclassifierは以下から選択。
# # - Silva138.1 V1/V2	"classifier_silva138_1_v12_2020.11.qza"
# # - Silva138.1 V4	"classifier_silva138_1_v4_2020.11.qza"
# # - Silva138 V1/V2	"classifier_silva138_v12_2020.11.qza"
# # - Silva138 V4	"classifier_silva138_v4_2020.11.qza"
# Silva 138.1の[update note](https://www.arb-silva.de/documentation/release-1381/)を必ず確認して欲しいですが、基本的には最新版を使うことを推奨します。
CLASSIFIER_PATH="/misc/work1/share/whole/qiime2/2020.11/classifier_silva138_1_v12_2020.11.qza"

bsub -J job9 -w "ended(job4)" -o Log/Job09.txt -e Error/Job09.txt -n 4 \
	qiime feature-classifier classify-sklearn \
	--i-classifier  $CLASSIFIER_PATH\
	--i-reads rep-seqs.qza --o-classification taxonomy.qza --p-n-jobs 4
# データベース大型化によるメモリ消費量増大に対応するため、使用コア数を16→4に削減

# 系統アサイン結果の視覚化
bsub -J job10 -w "ended(job9)" -o Log/Job10.txt -e Error/Job10.txt \
	qiime metadata tabulate \
	--m-input-file taxonomy.qza \
	--o-visualization taxonomy.qzv
# "unidentified"はSilvaDB中に含まれるが系統は未同定であることを示す


# 積み上げ式棒グラフ化
bsub -J job11 -w "ended(job10)" -o Log/Job11.txt -e Error/Job11.txt \
	qiime taxa barplot \
	--i-table table.qza \
	--i-taxonomy taxonomy.qza \
	--m-metadata-file Map.txt \
	--o-visualization taxa-bar-plots.qzv

# アライメント
bsub -J job12 -w "ended(job4)" -o Log/Job12.txt -e Error/Job12.txt -n 16 \
	qiime alignment mafft \
	--i-sequences rep-seqs.qza \
	--o-alignment aligned-rep-seqs.qza \
	--p-n-threads 16

# アライメントをフィルター
bsub -J job13 -w "ended(job12)" -o Log/Job13.txt -e Error/Job13.txt \
	qiime alignment mask \
	--i-alignment aligned-rep-seqs.qza \
	--o-masked-alignment masked-aligned-rep-seqs.qza

# fasttreeで系統樹作成
# # fasttree
bsub -J job14 -w "ended(job13)" -o Log/Job14.txt -e Error/Job14.txt -n 16 \
	qiime phylogeny fasttree \
	--i-alignment masked-aligned-rep-seqs.qza \
	--o-tree unrooted-tree.qza \
	--p-n-threads 16
# # rooting
bsub -J job15 -w "ended(job14)" -o Log/Job15.txt -e Error/Job15.txt \
	qiime phylogeny midpoint-root \
	--i-tree unrooted-tree.qza \
	--o-rooted-tree rooted-tree.qza
```

### QIIME2の実行コマンド3(～最後まで)

**depthを決定して実行コマンド3へ**

#### α,β多様性計算

>**depthはtable.qzvを見て決定→できれば5000リード/sample以上はほしい**

```bash
bsub -J job16 -w "ended(job15)" -o Log/Job16.txt -e Error/Job16.txt -n 1 \
	qiime diversity core-metrics-phylogenetic \
	--i-phylogeny rooted-tree.qza \
	--i-table table.qza \
	--p-sampling-depth 5000 \
	--m-metadata-file Map.txt \
	--p-n-jobs-or-threads 1 \
	--output-dir core-metrics-results
# （注意） 16コアだと並列化エラーを起こしやすい

bsub -J job17 -w "ended(job15)" -o Log/Job17.txt -e Error/Job17.txt \
	qiime diversity alpha-rarefaction \
	--i-table table.qza \
	--i-phylogeny rooted-tree.qza \
	--p-max-depth 5000 \
	--m-metadata-file Map.txt \
	--o-visualization alpha-rarefaction.qzv

# Familyレベルでまとめてfeature tableを作る→相対値変換→biom変換→tsv変換
# # Taxa collapse
bsub -J job18a -w "ended(job9)" -o Log/Job18a.txt -e Error/Job18a.txt \
	qiime taxa collapse \
	--i-table table.qza \
	--i-taxonomy taxonomy.qza \
	--p-level 5 \
	--output-dir family_table

# # Convert into relative abundance
bsub -J job18b -w "ended(job18a)" -o Log/Job18b.txt -e Error/Job18b.txt \
	qiime feature-table relative-frequency \
	--i-table family_table/collapsed_table.qza \
	--o-relative-frequency-table family_table/relative_table

# # Export biom
bsub -J job18c -w "ended(job18b)" -o Log/Job18c.txt -e Error/Job18c.txt \
	qiime tools export \
	--input-path family_table/relative_table.qza \
	--output-path family_table/biom

# # Convert biom into tsv
bsub -J job18d -w "ended(job18c)" -o Log/Job18d.txt -e Error/Job18d.txt \
biom convert \
	-i family_table/biom/feature-table.biom \
	-o family_table/relative_table.txt \
	--to-tsv

# Familyレベルのheatmap
bsub -J job19 -w "ended(job18a)" -o Log/Job19.txt -e Error/Job19.txt \
	qiime feature-table heatmap \
	--i-table family_table/collapsed_table.qza \
	--output-dir heatmap

# 代表配列の相同性Top hitを抽出(vs NCBI)
bsub -J job20 -w "ended(job7)" -o Log/Job20.txt -e Error/Job20.txt \
	vsearch --usearch_global rep_seq/dna-sequences.fasta \
	--db /misc/work1/share/whole/ncbi/191218NCBI_16Smod.fasta \
	--id 0.0 --maxaccepts 1 \
	--qmask none \
	--userfields query+target+id+qcov+ids+mism+gaps \
	--userout vsearch/top1hit.txt \
	--alnout vsearch/align.txt \
	--query_cov 0.85
# 相同性参照データベース NCBI 16S RefSeq recordsの指定

# 生リードファイルの削除
# # （job1にてqzaファイルへ集約のため）
bsub -J job21 -w "ended(job20)" -o Log/Job21.txt -e Error/Job21.txt \
	rm -rf ./fastqgz/
```

### オプション1

```bash
# QIIME2結果の可視化コマンド(export一覧)

# # dada2結果
bsub -J job22 -w "ended(job5)" -o Log/Job22.txt -e Error/Job22.txt \
	qiime tools export \
	--input-path dada2out/denoising_stats.qzv \
	--output-path visualizations/denoise_summary

# # feature table summary
bsub -J job23 -w "ended(job6)" -o Log/Job23.txt -e Error/Job23.txt \
	qiime tools export \
	--input-path table.qzv \
	--output-path visualizations/featuretable_summary

# # 系統アサイン結果
bsub -J job24a -w "ended(job10)" -o Log/Job24a.txt -e Error/Job24a.txt \
	qiime tools export \
	--input-path taxonomy.qzv \
	--output-path visualizations/taxonomy

# # 積み上げ式棒グラフ
bsub -J job24b -w "ended(job11)" -o Log/Job24b.txt -e Error/Job24b.txt \
	qiime tools export \
	--input-path taxa-bar-plots.qzv \
	--output-path visualizations/barplots

# # α多様性
bsub -J job25a -w "ended(job16)" -o Log/Job25a.txt -e Error/Job25a.txt \
	qiime diversity alpha-group-significance \
	--i-alpha-diversity core-metrics-results/faith_pd_vector.qza \
	--m-metadata-file Map.txt \
	--o-visualization visualizations/alpha_diversity/faith_pd.qzv

bsub -J job25b -w "ended(job25a)" -o Log/Job25b.txt -e Error/Job25b.txt \
	qiime tools export \
	--input-path visualizations/alpha_diversity/faith_pd.qzv \
	--output-path visualizations/alpha_diversity/faith_pd
bsub -J job25c -w "ended(job16)" -o Log/Job25c.txt -e Error/Job25c.txt \
	qiime diversity alpha-group-significance \
	--i-alpha-diversity core-metrics-results/evenness_vector.qza \
	--m-metadata-file Map.txt \
	--o-visualization visualizations/alpha_diversity/evenness.qzv
bsub -J job25d -w "ended(job25c)" -o Log/Job25d.txt -e Error/Job25d.txt \
	qiime tools export \
	--input-path visualizations/alpha_diversity/evenness.qzv \
	--output-path visualizations/alpha_diversity/evenness
bsub -J job25e -w "ended(job16)" -o Log/Job25e.txt -e Error/Job25e.txt \
	qiime diversity alpha-group-significance \
	--i-alpha-diversity core-metrics-results/observed_features_vector.qza \
	--m-metadata-file Map.txt \
	--o-visualization visualizations/alpha_diversity/observed_features_vector.qzv
bsub -J job25f -w "ended(job25e)" -o Log/Job25f.txt -e Error/Job25f.txt \
	qiime tools export \
	--input-path visualizations/alpha_diversity/observed_features_vector.qzv \
	--output-path visualizations/alpha_diversity/observed_otus
bsub -J job25g -w "ended(job16)" -o Log/Job25g.txt -e Error/Job25g.txt \
	qiime diversity alpha-group-significance \
	--i-alpha-diversity core-metrics-results/shannon_vector.qza \
	--m-metadata-file Map.txt \
	--o-visualization visualizations/alpha_diversity/shannon_vector.qzv
bsub -J job25h -w "ended(job25g)" -o Log/Job25h.txt -e Error/Job25h.txt \
	qiime tools export \
	--input-path visualizations/alpha_diversity/shannon_vector.qzv \
	--output-path visualizations/alpha_diversity/shannon

# # β多様性
bsub -J job26a -w "ended(job16)" -o Log/Job26a.txt -e Error/Job26a.txt \
qiime tools export \
--input-path core-metrics-results/bray_curtis_emperor.qzv \
--output-path visualizations/beta_diversity/bray_curtis
bsub -J job26b -w "ended(job16)" -o Log/Job26b.txt -e Error/Job26b.txt \
qiime tools export \
--input-path core-metrics-results/jaccard_emperor.qzv \
--output-path visualizations/beta_diversity/jaccard
bsub -J job26c -w "ended(job16)" -o Log/Job26c.txt -e Error/Job26c.txt \
qiime tools export \
--input-path core-metrics-results/unweighted_unifrac_emperor.qzv \
--output-path visualizations/beta_diversity/unweighted_unifrac
bsub -J job26d -w "ended(job16)" -o Log/Job26d.txt -e Error/Job26d.txt \
qiime tools export \
--input-path core-metrics-results/weighted_unifrac_emperor.qzv \
--output-path visualizations/beta_diversity/weighted_unifrac

# # alpha-rarefactin plot
bsub -J job27 -w "ended(job17)" -o Log/Job27.txt -e Error/Job27.txt \
qiime tools export \
--input-path alpha-rarefaction.qzv \
--output-path visualizations/alpha-rarefaction_plot

# # heatmap
bsub -J job28 -w "ended(job19)" -o Log/Job28.txt -e Error/Job28.txt \
qiime tools export \
--input-path heatmap/visualization.qzv \
--output-path visualizations/heatmap
```

### オプション2

```bash
# 正常完了ジョブのErrorファイルを削除
find Error/ -empty | xargs rm
```