process BCFTOOLS_SETGT_VAF {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.20--h8b25389_0':
        'biocontainers/bcftools:1.20--h8b25389_0' }"

    input:
    tuple val(meta), path(vcf), path(tbi)

    output:
    tuple val(meta), path("*.vcf.gz"), emit: vcf
    tuple val(meta), path("*.tbi")   , emit: tbi
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    # Correct genotypes based on VAF thresholds for all three samples in trio
    # 0/1 with VAF < 0.15 -> 0/0 (clearly homozygous reference, miscalled)
    # 0/1 with VAF > 0.85 -> 1/1 (clearly homozygous alternate, miscalled)
    
    bcftools +setGT ${vcf} \
        -- -t q -n c:'0/0' -i 'GT[0]="0/1" && FORMAT/AD[0:1]/(FORMAT/AD[0:0]+FORMAT/AD[0:1])<0.15' \
    | bcftools +setGT \
        -- -t q -n c:'1/1' -i 'GT[0]="0/1" && FORMAT/AD[0:1]/(FORMAT/AD[0:0]+FORMAT/AD[0:1])>0.85' \
    | bcftools +setGT \
        -- -t q -n c:'0/0' -i 'GT[1]="0/1" && FORMAT/AD[1:1]/(FORMAT/AD[1:0]+FORMAT/AD[1:1])<0.15' \
    | bcftools +setGT \
        -- -t q -n c:'1/1' -i 'GT[1]="0/1" && FORMAT/AD[1:1]/(FORMAT/AD[1:0]+FORMAT/AD[1:1])>0.85' \
    | bcftools +setGT \
        -- -t q -n c:'0/0' -i 'GT[2]="0/1" && FORMAT/AD[2:1]/(FORMAT/AD[2:0]+FORMAT/AD[2:1])<0.15' \
    | bcftools +setGT \
        -- -t q -n c:'1/1' -i 'GT[2]="0/1" && FORMAT/AD[2:1]/(FORMAT/AD[2:0]+FORMAT/AD[2:1])>0.85' \
    | bgzip -c > ${prefix}.vcf.gz

    bcftools index -t ${prefix}.vcf.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.vcf.gz
    touch ${prefix}.vcf.gz.tbi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}