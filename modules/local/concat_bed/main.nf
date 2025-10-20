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
    tuple val(meta), path(beds)

    output:
    tuple val(meta), path("*.bed"), emit: bed
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def bed_files = (beds instanceof List) ? beds.join(' ') : beds

    """
    set -euo pipefail
    
    # Step 1-4: Concatenate, clean, sort and deduplicate BED files
    cat ${bed_files} \\
        | awk 'BEGIN{OFS="\\t"} { if(NF>=3 && \$1!="" && \$2!="" && \$3!=""){print \$1,\$2,\$3} }' \\
        | sort -k1,1 -k2,2n \\
        | uniq ${args} > ${prefix}_svs_concatenated.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n1 | cut -d' ' -f4)
        awk: \$(awk --version | head -n1)
        sort: \$(sort --version | head -n1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo -e "chr1\\t1000\\t2000\\nchr2\\t3000\\t4000" > ${prefix}_svs_concatenated.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(echo "5.0.0")
        awk: \$(echo "gawk 5.0.0")
        sort: \$(echo "sort 8.30")
    END_VERSIONS
    """
}