#!/usr/bin/env nextflow

process VCF_CHECK {
    tag "$meta.id"
    label 'process_medium'
    
    container "/home/u0030001/nf-updhmm_zenodo/updhmm-new_1.3.2.sif"

    input:
    tuple val(meta), path(vcf), path(tbi)

    output:
    tuple val(meta), path("*.processed.rds"), emit: processed_vcf

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def genome_build = meta.genome_build ?: params.genome_build ?: "hg38"
    def verbose = task.ext.verbose ? "--verbose" : ""
    
    """
    vcf_check.r \\
        --input ${vcf} \\
        --output_prefix ${prefix} \\
        --genome_build ${genome_build} \\
        ${verbose} \\
        ${args}

    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.processed.rds
    
    """
}
