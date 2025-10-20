#!/usr/bin/env nextflow

process COLLAPSE_EVENTS {
    tag "$meta.id"
    label 'process_medium'
    
    container "/home/u0030001/nf-updhmm_zenodo/updhmm-new_1.3.2.sif"

    input:
    tuple val(meta), path(upd_events_rds)

    output:
    tuple val(meta), path("*.upd_collapsed.txt"), emit: upd_collapsed_txt
    tuple val(meta), path("*.upd_collapsed.rds"), emit: upd_collapsed_rds
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def verbose = task.ext.verbose ? "--verbose" : ""
    
    """
    collapse_events.r \\
        --input ${upd_events_rds} \\
        --output_prefix ${prefix} \\
        ${verbose} \\
        ${args}

    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.upd_collapsed.txt
    touch ${prefix}.upd_collapsed.rds
    
    """
}
