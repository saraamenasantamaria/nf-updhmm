//
// This process takes multiple BED files containing structural variant (SV) regions 
// from different sources (e.g. proband, mother, father), concatenates them into a 
// single file, keeps only valid BED fields (chromosome, start, end), sorts the entries 
// by genomic coordinates, removes duplicates, and produces a clean, unified BED file.
//

process CUSTOM_BEDCONCAT {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'ubuntu:20.04' }"

    input:
    tuple val(meta), path(beds, stageAs: 'input_beds/*')  // Multiple BED files to merge

    output:
    tuple val(meta), path("*.bed"), emit: bed
    path "versions.yml"           , emit: versions, topic: 'versions'
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    cat input_beds/*.bed \\
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