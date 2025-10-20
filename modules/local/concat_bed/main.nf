//
// This process takes multiple BED files containing structural variant (SV) regions 
// from different sources (e.g. proband, mother, father), concatenates them into a 
// single file, keeps only valid BED fields (chromosome, start, end), sorts the entries 
// by genomic coordinates, removes duplicates, and produces a clean, unified BED file.
//

process CONCAT_BED {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(beds, stageAs: 'input_beds/*')

    output:
    tuple val(meta), path("*.bed"), emit: bed
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args   = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # Concatenate, clean, sort and deduplicate BED files
    cat input_beds/*.bed \\
        | awk 'BEGIN {OFS="\\t"} {
            # Keep only valid BED entries with 3 fields
            if (NF >= 3 && \$1 != "" && \$2 != "" && \$3 != "") {
                print \$1, \$2, \$3
            }
        }' \\
        | sort -k1,1 -k2,2n \\
        | uniq ${args} \\
        > ${prefix}.concatenated.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version 2>&1 | head -n1 | sed 's/^.*version //; s/ .*\$//')
        awk: \$(awk --version 2>&1 | head -n1 | sed 's/^GNU Awk //; s/,.*//')
        sort: \$(sort --version 2>&1 | head -n1 | sed 's/^.* //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    touch ${prefix}.concatenated.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: 5.0.0
        awk: 5.0.0
        sort: 8.30
    END_VERSIONS
    """
}