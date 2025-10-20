#!/usr/bin/env nextflow

process UPDHMM_VCFCHECK {
    tag "$meta.id"
    label 'process_high'
    
    container "/home/u0030001/nf-updhmm_zenodo/updhmm_v1.5.2.sif"

    input:
    tuple val(meta), path(vcf), path(tbi)

    output:
    tuple val(meta), path("*.processed.rds")    , emit: processed_vcf
    tuple val(meta), path("*.R_sessionInfo.log"), emit: session_info
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    genome_build = meta.genome_build ?: params.genome_build ?: "hg38"
    verbose = task.ext.verbose ?: true
    args = task.ext.args ?: ''
    
    template 'vcfcheck.R'

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    #!/usr/bin/env Rscript
    
    # Create empty output files
    saveRDS(list(), file = "${prefix}.processed.rds")
    
    # Session info
    writeLines("R session info stub", "${prefix}.R_sessionInfo.log")
    
    # Generate versions.yml
    r.version <- strsplit(version[['version.string']], ' ')[[1]][3]
    updhmm.version <- as.character(packageVersion('UPDhmm'))
    variantannotation.version <- as.character(packageVersion('VariantAnnotation'))
    
    writeLines(
        c(
            '"${task.process}":',
            paste0('    r-base: "', r.version, '"'),
            paste0('    bioconductor-updhmm: "', updhmm.version, '"'),
            paste0('    bioconductor-variantannotation: "', variantannotation.version, '"')
        ),
        'versions.yml'
    )
    """
}