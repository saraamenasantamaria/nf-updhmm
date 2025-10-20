//
// Perform GVCF combination and genotyping operations
//
// This workflow combines individual GVCF files from trio members using GATK4 CombineGVCFs,
// then performs joint genotyping with GenotypeGVCFs to produce a final VCF.
// This approach is specifically designed for GVCF inputs and follows GATK best practices.
//

include { GATK4_COMBINEGVCFS                               } from '../../../modules/nf-core/gatk4/combinegvcfs/main'
include { GATK4_GENOTYPEGVCFS                              } from '../../../modules/nf-core/gatk4/genotypegvcfs/main'
include { BCFTOOLS_ANNOTATE as BCFTOOLS_DELETE_ANNOTATIONS } from '../../../modules/nf-core/bcftools/annotate/main'

workflow GVCF_COMBINE {
    
    take:
    ch_gvcfs    // channel: [val(meta), path(gvcfs), path(tbis)]
    val_fasta  // path to reference fasta
    val_fai    // path to fasta index
    val_dict   // path to reference dict
    
    main:
    ch_versions = Channel.empty()

    //
    // Combine GVCFs from trio members
    //
    GATK4_COMBINEGVCFS(
        ch_gvcfs,
        val_fasta,
        val_fai,
        val_dict
    )
    ch_versions = ch_versions.mix(GATK4_COMBINEGVCFS.out.versions)

    //
    // Prepare input for GenotypeGVCFs
    //
    ch_genotype_input = GATK4_COMBINEGVCFS.out.combined_gvcf
        .map { meta, gvcf ->
            def tbi = file("${gvcf}.tbi")
            [ meta, gvcf, tbi, [], [] ]
        }

    //
    // Prepare reference files as tuples with empty meta
    //
    ch_fasta = Channel.value([ [:], val_fasta ])
    ch_fai   = Channel.value([ [:], val_fai ])
    ch_dict  = Channel.value([ [:], val_dict ])
    
    //
    // Set dbSNP files as empty (optional parameters not used)
    //
    ch_dbsnp     = Channel.value([ [:], [] ])
    ch_dbsnp_tbi = Channel.value([ [:], [] ])

    //
    // Perform joint genotyping to convert combined GVCF to VCF
    //
    GATK4_GENOTYPEGVCFS(
        ch_genotype_input,
        ch_fasta,
        ch_fai,
        ch_dict,
        ch_dbsnp,
        ch_dbsnp_tbi
    )
    ch_versions = ch_versions.mix(GATK4_GENOTYPEGVCFS.out.versions)
    
    //
    // Prepare input for annotation removal
    //
    ch_annotate_input = GATK4_GENOTYPEGVCFS.out.vcf
        .join(GATK4_GENOTYPEGVCFS.out.tbi)
        .map { meta, vcf, tbi ->
            [ meta, vcf, tbi, [], [] ]
        }

    //
    // Remove unused annotations from VCF files
    //
    BCFTOOLS_DELETE_ANNOTATIONS(
        ch_annotate_input,
        [],
        [],
        []
    )
    ch_versions = ch_versions.mix(BCFTOOLS_DELETE_ANNOTATIONS.out.versions)

    //
    // Prepare final output channel with VCF and its index
    //
    ch_final_vcfs = BCFTOOLS_DELETE_ANNOTATIONS.out.vcf
        .join(BCFTOOLS_DELETE_ANNOTATIONS.out.tbi)
    
    emit:
    vcf      = ch_final_vcfs  // channel: [val(meta), path(vcf), path(tbi)]
    versions = ch_versions    // channel: [path(versions.yml)]
}