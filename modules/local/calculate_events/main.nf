#!/usr/bin/env nextflow

process CALCULATE_EVENTS {
    tag "$meta.id"
    label 'process_updhmm'
    
    container "/home/u0030001/nf-updhmm_zenodo/updhmm.sif"

    input:
    tuple val(meta), path(processed_vcf_rds)

    output:
    tuple val(meta), path("*.upd_events.txt"), emit: upd_events_txt
    tuple val(meta), path("*.upd_events.rds"), emit: upd_events_rds

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def verbose = task.ext.verbose ? "--verbose" : ""
    def cpus = task.cpus ?: 1
    def add_ratios = params.add_ratios ? "--add_ratios" : ""
    
    """
    calculate_events.r \\
        --input ${processed_vcf_rds} \\
        --output_prefix ${prefix} \\
        --cpus ${cpus} \\
        ${verbose} \\
        ${add_ratios} \\
        ${args}

    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.upd_events.txt
    touch ${prefix}.upd_events.rds
    
    """
}