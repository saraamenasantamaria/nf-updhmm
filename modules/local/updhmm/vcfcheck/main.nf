process UPDHMM_VCFCHECK {
    tag "$meta.id"
    label 'process_medium'
    
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
    template 'vcfcheck.R'

    stub:
    """
    touch ${meta.id}.processed.rds
    touch ${meta.id}.R_sessionInfo.log
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(Rscript -e "cat(paste(R.version[['major']], R.version[['minor']], sep='.'))")
        bioconductor-updhmm: \$(Rscript -e "library(UPDhmm); cat(as.character(packageVersion('UPDhmm')))")
        bioconductor-variantannotation: \$(Rscript -e "library(VariantAnnotation); cat(as.character(packageVersion('VariantAnnotation')))")
    END_VERSIONS
    """
}