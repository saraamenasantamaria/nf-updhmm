#!/usr/bin/env nextflow

process UPDHMM_CALCULATEEVENTS {
    tag "$meta.id"
    label 'process_updhmm'
    
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
    prefix     = task.ext.prefix ?: "${meta.id}"
    verbose    = task.ext.verbose ?: true
    add_ratios = task.ext.add_ratios ?: params.add_ratios ?: false
    cpus       = task.cpus ?: 1
    args       = task.ext.args ?: ''
    
    template 'calculateevents.R'
    
    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    #!/usr/bin/env Rscript
    
    # Create empty output files
    write.table(data.frame(), file = "${prefix}.upd_events.txt", sep = "\\t")
    saveRDS(list(), file = "${prefix}.upd_events.rds")
    writeLines("R session info stub", "${prefix}.R_sessionInfo.log")
    
    # Generate versions.yml
    r.version <- strsplit(version[['version.string']], ' ')[[1]][3]
    updhmm.version <- as.character(packageVersion('UPDhmm'))
    biocparallel.version <- as.character(packageVersion('BiocParallel'))
    
    writeLines(
        c(
            '"${task.process}":',
            paste0('    r-base: "', r.version, '"'),
            paste0('    bioconductor-updhmm: "', updhmm.version, '"'),
            paste0('    bioconductor-biocparallel: "', biocparallel.version, '"')
        ),
        'versions.yml'
    )
    """
}
