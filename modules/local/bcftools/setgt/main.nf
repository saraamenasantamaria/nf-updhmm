//
// Convert missing genotypes in VCF files to homozygous reference (0/0).
//
process BCFTOOLS_SETGT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.20--h8b25389_0':
        'biocontainers/bcftools:1.20--h8b25389_0' }"

    input:
    tuple val(meta), path(vcf), path(tbi) // tbi is optional, pass [] if not available

    output:
    tuple val(meta), path("*.vcf.gz"), emit: vcf
    tuple val(meta), path("*.vcf.gz.tbi"), emit: tbi
    path "versions.yml", emit: versions, topic: 'versions'
    
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: '-- -t . -n 0/0'
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

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.vcf.gz
    touch ${prefix}.vcf.gz.tbi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: 1.20
    END_VERSIONS
    """
}