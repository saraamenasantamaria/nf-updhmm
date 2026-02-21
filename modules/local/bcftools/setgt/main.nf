process BCFTOOLS_SETGT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.23--h3a4d415_0':
        'biocontainers/bcftools:1.23--h3a4d415_0' }"

    input:
    tuple val(meta), path(vcf), path(tbi) // tbi is optional, pass [] if not available

    output:
    tuple val(meta), path("*.vcf.gz")    , emit: vcf
    tuple val(meta), path("*.vcf.gz.tbi"), emit: tbi
    tuple val("${task.process}"), val("bcftools"), eval("bcftools --version | head -n1 | cut -d' ' -f2"), emit: versions_bcftools, topic: versions
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    // Prevent input/output name collision
    if ("${vcf}" == "${prefix}.vcf.gz") {
        error "Input and output names are the same. Set 'ext.prefix' in module configuration to disambiguate!"
    }
    
    """
    bcftools +setGT \\
        ${vcf} \\
        --no-version \\
        -Oz \\
        -o ${prefix}.vcf.gz \\
        ${args}
    
    bcftools index -t ${prefix}.vcf.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.vcf.gz
    touch ${prefix}.vcf.gz.tbi
    
    """
}