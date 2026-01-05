process CUSTOM_BEDCONCAT {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    tuple val(meta), path(beds)  // Multiple BED files to merge

    output:
    tuple val(meta), path("*.bed"), emit: bed
    path "versions.yml"           , emit: versions
    
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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        coreutils: \$(sort --version 2>&1 | head -n1 | sed 's/^.* //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    touch ${prefix}.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        coreutils: 9.5
    END_VERSIONS
    """
}