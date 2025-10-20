#!/usr/bin/env nextflow

process UPDHMM_COLLAPSEEVENTS {
    tag "$meta.id"
    label 'process_medium'
    
    container "/home/u0030001/nf-updhmm_zenodo/updhmm_v1.5.2.sif"

    input:
    tuple val(meta), path(upd_events_rds)

    output:
    tuple val(meta), path("*.upd_collapsed.txt")   , emit: upd_collapsed_txt
    tuple val(meta), path("*.upd_collapsed.rds")   , emit: upd_collapsed_rds
    tuple val(meta), path("*.R_sessionInfo.log")   , emit: session_info
    path "versions.yml"                            , emit: versions
    
    when:
    task.ext.when == null || task.ext.when

    script:
    prefix  = task.ext.prefix ?: "${meta.id}"
    verbose = task.ext.verbose ?: true
    args    = task.ext.args ?: ''
    
    template 'collapseevents.R'
    
    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    #!/usr/bin/env Rscript
    
    # Create empty output files
    write.table(data.frame(), file = "${prefix}.upd_collapsed.txt", sep = "\\t")
    saveRDS(list(), file = "${prefix}.upd_collapsed.rds")
    writeLines("R session info stub", "${prefix}.R_sessionInfo.log")
    
    # Generate versions.yml
    r.version <- strsplit(version[['version.string']], ' ')[[1]][3]
    updhmm.version <- as.character(packageVersion('UPDhmm'))
    
    writeLines(
        c(
            '"${task.process}":',
            paste0('    r-base: "', r.version, '"'),
            paste0('    bioconductor-updhmm: "', updhmm.version, '"')
        ),
        'versions.yml'
    )
    """
}