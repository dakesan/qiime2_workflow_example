from subprocess import Popen
from pathlib import Path


def main():
    INPUT1 = Path("q2_core_data/sequence/demux.qza").resolve()
    VIS_DEMUX = Path("visualize/demux/demux.qzv").resolve()
    REPSEQ = INPUT1.parent / "rep_seq"
    M_ALIGN = Path("q2_core_data/sequence/aligned_rep_seq.qza")
    ALIGN = Path("q2_core_data/sequence/masked_aligned_rep_seq.qza")
    TREE = Path("q2_core_data/taxonomy/rooted_tree.qza")
    UNROOT_TREE = Path("q2_core_data/taxonomy/unrooted_tree.qza")
    CLASSIFIER = "gg-13-8-99-515-806-nb-classifier.qza"
    TAXONOMY = Path("q2_core_data/taxonomy/taxonomy.qza")

    pathlist = [
        INPUT1,
        VIS_DEMUX,
        REPSEQ,
        M_ALIGN,
        ALIGN,
        TREE,
        UNROOT_TREE,
        TAXONOMY,
    ]
    for path in pathlist:
        path.parent.mkdir(exist_ok=True, parents=True)

    ps = Popen(
        [
            "qiime",
            "demux",
            "summarize",
            "--i-data",
            str(INPUT1),
            "--o-visualization",
            str(VIS_DEMUX),
        ]
    )
    ps.wait()

    ps = Popen(
        [
            "qiime",
            "dada2",
            "denoise-single",
            "--p-trim-left",
            "13",
            "--p-trunc-len",
            "150",
            "--i-demultiplexed-seqs",
            str(INPUT1),
            "--o-representative-sequences",
            str(REPSEQ),
            "--o-table",
            "--o-denoising-stats",
            "--p-n-threads",
            "4",
        ]
    )
    ps.wait()

    ps = Popen(
        [
            "qiime",
            "phylogeny",
            "align-to-tree-mafft-fasttree",
            "--i-sequences",
            REPSEQ,
            "--o-alignment",
            ALIGN,
            "--o-masked-alignment",
            M_ALIGN,
            "--o-tree",
            UNROOT_TREE,
            "--o-rooted-tree",
            TREE,
        ]
    )

    ps2 = Popen(
        [
            "qiime",
            "feature-classifier",
            "classify-sklearn",
            "--i-classifier",
            CLASSIFIER,
            "--i-reads",
            REPSEQ,
            "--o-classification",
            TAXONOMY,
        ]
    )

    ps.wait()
    ps2.wait()
