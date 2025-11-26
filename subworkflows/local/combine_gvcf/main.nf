//
// Perform GVCF combination and genotyping operations
//
// This workflow combines individual GVCF files from trio members using GATK4 CombineGVCFs,
// then performs joint genotyping with GenotypeGVCFs to produce a final VCF.
// This approach is specifically designed for GVCF inputs and follows GATK best practices.
//

include { GATK4_COMBINEGVCFS  } from '../../../modules/nf-core/gatk4/combinegvcfs/main'
include { GATK4_GENOTYPEGVCFS } from '../../../modules/nf-core/gatk4/genotypegvcfs/main'
include { BCFTOOLS_ANNOTATE as BCFTOOLS_DELETE_ANNOTATIONS } from '../../../modules/nf-core/bcftools/annotate/main'

workflow COMBINE_GVCF {
    
    take:
    gvcfs_ch    // channel: [meta, gvcfs, tbis]
    
    main:
    ch_versions = Channel.empty()

    // Step 1: Combine GVCFs from trio members using GATK4 CombineGVCFs
    GATK4_COMBINEGVCFS(
        gvcfs_ch,
        params.fasta,
        params.fai,
        params.dict
    )
    ch_versions = ch_versions.mix(GATK4_COMBINEGVCFS.out.versions)

    // Step 2: Prepare input for GenotypeGVCFs
    genotype_input_ch = GATK4_COMBINEGVCFS.out.combined_gvcf
        .map { meta, gvcf ->
            def tbi = file("${gvcf}.tbi")
            tuple(meta, gvcf, tbi, [], []) 
        }

    // Prepare reference files as tuples with empty meta
    fasta_tuple = Channel.value([[:], params.fasta])
    fai_tuple = Channel.value([[:], params.fai])
    dict_tuple = Channel.value([[:], params.dict])
    
    // Set dbSNP files as empty (optional parameters not used)
    dbsnp_tuple = Channel.value([[:], []])
    dbsnp_tbi_tuple = Channel.value([[:], []])

    // Step 3: Perform joint genotyping to convert combined GVCF to VCF
    GATK4_GENOTYPEGVCFS(
        genotype_input_ch,
        fasta_tuple,
        fai_tuple,
        dict_tuple,
        dbsnp_tuple,
        dbsnp_tbi_tuple
    )
    ch_versions = ch_versions.mix(GATK4_GENOTYPEGVCFS.out.versions)
    
    // Step 4: Prepare input for annotation removal
    annotate_input = GATK4_GENOTYPEGVCFS.out.vcf
        .join(GATK4_GENOTYPEGVCFS.out.tbi)
        .map { meta, vcf, tbi ->
            tuple(meta, vcf, tbi, [], [])
        }

    // Step 5: Remove unused annotations from VCF files
    BCFTOOLS_DELETE_ANNOTATIONS(annotate_input, [], [], [])
    ch_versions = ch_versions.mix(BCFTOOLS_DELETE_ANNOTATIONS.out.versions)

    // Step 6: Prepare final output channel with VCF and its index
    final_vcfs_ch = BCFTOOLS_DELETE_ANNOTATIONS.out.vcf
        .join(BCFTOOLS_DELETE_ANNOTATIONS.out.tbi)
        .map { meta, vcf, tbi ->
            tuple(meta, vcf, tbi)
        }
    
    emit:
    vcfs     = final_vcfs_ch     // channel: [meta, vcf, tbi]
    versions = ch_versions       // channel: versions.yml
}