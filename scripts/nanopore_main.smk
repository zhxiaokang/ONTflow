configfile: "../config/config.yaml"

barcode_file = config["BARCODE_FILE"]
seq_summary = config["SEQ_SUMMARY"]
dir_fastq = config["DIR_FASTQ"]
dir_output = config["DIR_OUTPUT"]
genome = config["GENOME"]
annot = config["ANNOTATE"]
trans = config["TRANSCRIPTOME"]
tx2gene = config["TX2GENE"]
id2symbol = config["ID2SYMBOL"]

with open(barcode_file) as f:
    barcode_indexes = list(barcode.strip() for barcode in f.readlines() if barcode.strip())

rule end:
    input:
        qc_report = dir_output + "/qc_sequence_report.html",
        gene_fusions = expand(dir_output + "/gene_fusions/gene_fusions_{barcode_index}.txt", barcode_index = barcode_indexes),
        quant_gene = expand(dir_output + "/gene_abundance/gene_abundance_{barcode_index}.tsv", barcode_index = barcode_indexes)

rule QC_sequence:
    input:
        seq_summary = seq_summary
    output:
        qc_report = dir_output + "/qc_sequence_report.html"
    shell:
        "pycoQC -f {input.seq_summary} -o {output.qc_report}"

rule trimming:
    input: dir_fastq + "/{barcode_index}"
    output: directory(dir_output+ "/trimming_barcode/{barcode_index}/{barcode_index}")
    params:
        outpath = dir_output+ "/trimming_barcode/{barcode_index}"
    shell:
        """
        guppy_barcoder --input_path {input} --save_path {params.outpath} --trim_barcodes --barcode_kits SQK-PCB109
        """

rule merge_fastq:
    input:
        fastq_dir = dir_output+ "/trimming_barcode/{barcode_index}/{barcode_index}"
    output:
        fastq_merge = dir_output+ "/trimming_barcode/{barcode_index}.fastq"
    shell:
        """
        for file in {input.fastq_dir}/*.fastq
        do
            cat $file >> {output.fastq_merge}
        done
        """

rule index_genome:
    input: genome = genome
    output: index_genome = genome + ".bwt"
    shell: "bwa index -a bwtsw {input}"

rule alignment:
    input:
        genome = genome,
        index_genome = genome + ".bwt",
        fastq_merge = dir_output+ "/trimming_barcode/{barcode_index}.fastq"
    output:
        sam = dir_output + "/SAM/aln_{barcode_index}.sam"
    shell:
        "bwa mem -x ont2d -t 12 {input.genome} {input.fastq_merge} > {output.sam}"

rule sam2bam_sort:
    input: sam = dir_output + "/SAM/aln_{barcode_index}.sam"
    output: bam = dir_output + "/BAM/aln_sort_{barcode_index}.bam"
    shell:
        "samtools sort -@ 12 -n -o {output.bam} {input.sam}"

rule gene_fusion:
    input:
        bam = dir_output + "/BAM/aln_sort_{barcode_index}.bam",
        annot = annot
    output:
        gene_fusions = dir_output + "/gene_fusions/gene_fusions_{barcode_index}.txt"
    shell:
        "LongGF {input.bam} {input.annot} 60 30 60 0 1 2 > {output.gene_fusions}"

rule index_trans:
    input:
        trans = trans
    output:
        index_trans = trans + ".mmi"
    shell:
        "minimap2 -x map-ont -d {output.index_trans} {input.trans}"

rule map2trans:
    input:
        index_trans = trans + ".mmi",
        fastq_merge = dir_output+ "/trimming_barcode/{barcode_index}.fastq"
    output:
        sam_trans = dir_output + "/SAM_trans/map_{barcode_index}.sam"
    shell:
        "minimap2 -t 12 -p 1.0 -N 100 --split-prefix=tmp_{wildcards.barcode_index} -a {input.index_trans} -ax splice {input.fastq_merge} > {output.sam_trans}"

rule sam2bam:
    input: sam_trans = dir_output + "/SAM_trans/map_{barcode_index}.sam"
    output: bam_trans = dir_output + "/BAM_trans/map_{barcode_index}.bam"
    shell:
        "samtools view -@ 12 -Sb {input.sam_trans} > {output.bam_trans}"

rule quantify_trans:
    input:
        trans = trans,
        bam_trans = dir_output + "/BAM_trans/map_{barcode_index}.bam"
    output:
        quant_salmon = directory(dir_output + "/quantification/salmon_{barcode_index}")
    shell:
        "salmon quant --noErrorModel -p 12 -t {input.trans} -l A -a {input.bam_trans} -o {output.quant_salmon} --writeUnmappedNames"

rule trans2gene:
    input:
        tx2gene = tx2gene,
        id2symbol = id2symbol,
        quant_salmon = dir_output + "/quantification/salmon_{barcode_index}"
    output:
        quant_gene = dir_output + "/gene_abundance/gene_abundance_{barcode_index}.tsv"
    params:
        quant_gene_dir = dir_output + "/gene_abundance"
    shell:
        "Rscript sum2gene.R {input.tx2gene} {input.id2symbol} {input.quant_salmon} {params.quant_gene_dir}"
