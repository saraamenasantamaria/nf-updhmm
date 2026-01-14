process UPDHMM_COLLAPSEEVENTS {
    tag "$meta.id"
    label 'process_medium'
    
    container "/home/u0030001/nf-updhmm_zenodo/updhmm_v1.5.3.sif"

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
    template 'collapseevents.R'
    
    stub:
    """
    touch ${meta.id}.upd_collapsed.txt
    touch ${meta.id}.upd_collapsed.rds
    touch ${meta.id}.R_sessionInfo.log
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-base: \$(Rscript -e "cat(paste(R.version[['major']], R.version[['minor']], sep='.'))")
        bioconductor-updhmm: \$(Rscript -e "library(UPDhmm); cat(as.character(packageVersion('UPDhmm')))")
    END_VERSIONS
    """
}