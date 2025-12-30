#!/usr/bin/env nextflow

process UPDHMM_CALCULATEEVENTS {
    tag "$meta.id"
    label 'process_high'
    
    container "/home/u0030001/nf-updhmm_zenodo/updhmm_v1.5.2.sif"

    input:
    tuple val(meta), path(processed_vcf_rds)

    output:
    tuple val(meta), path("*.upd_events.txt")   , emit: upd_events_txt
    tuple val(meta), path("*.upd_events.rds")   , emit: upd_events_rds
    tuple val(meta), path("*.R_sessionInfo.log"), emit: session_info
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when
    
    script:
    template 'calculateevents.R'
    
    stub:
    """
    touch ${meta.id}.upd_events.txt
    touch ${meta.id}.upd_events.rds
    touch ${meta.id}.R_sessionInfo.log
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(Rscript -e "cat(paste(R.version[['major']], R.version[['minor']], sep='.'))")
        bioconductor-updhmm: \$(Rscript -e "library(UPDhmm); cat(as.character(packageVersion('UPDhmm')))")
        bioconductor-biocparallel: \$(Rscript -e "library(BiocParallel); cat(as.character(packageVersion('BiocParallel')))")
    END_VERSIONS
    """
}
