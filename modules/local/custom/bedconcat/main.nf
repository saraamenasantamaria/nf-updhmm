process CUSTOM_BEDCONCAT {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/coreutils:9.5' :
    'biocontainers/coreutils:9.5' }"

    input:
    tuple val(meta), path(beds)  // Multiple BED files to merge

    output:
    tuple val(meta), path("*.bed"), emit: bed
    tuple val("${task.process}"), val("coreutils"), eval("coreutils --version | head -n1 | cut -d' ' -f4"), emit: versions_coreutils, topic: versions
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    cat *.bed \\
        | awk 'BEGIN {OFS="\\t"} {
            if (NF >= 3 && \$1 != "" && \$2 != "" && \$3 != "") {
                print \$1, \$2, \$3
            }
        }' \\
        | sort -k1,1 -k2,2n \\
        | uniq ${args} \\
        > ${prefix}.bed
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    touch ${prefix}.bed
    """
}