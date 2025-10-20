//
// Apply hard filters to produce the final preprocessed VCF per family
//
// This workflow applies sequential filters to VCFs to ensure high-confidence variants.
// Filters include:
//   1) Keep only biallelic sites
//   2) Exclude variants where all trio members are homozygous reference (0/0 or 0|0)
//   3) Enforce minimum genotype quality (GQ) and depth (DP) across the trio
//   4) Exclude problematic genomic regions (centromeres, segmental duplications, HLA/KIR)
//
// Notes:
//   - SETGT is applied conditionally if params.perform_intersection is false.
//   - All bcftools arguments are configured via conf/modules.config.
//

include { SETGT                                             } from '../../../modules/local/setGT/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_BIALLELIC         } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_REFHOMO_EXCLUDE    } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_QUAL_MIN           } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_EXCL_ALL   } from '../../../modules/nf-core/bcftools/view/main'

workflow FILTER_LOWCONF {
    
    take:
    vcfs_ch    // channel: [meta, vcf, tbi]
    
    main:
    ch_versions = Channel.empty()
    
    // Helper function: combine VCF with index for sequential filtering
    def combineVcfIndex = { vcf_ch, index_ch ->
        return vcf_ch.join(index_ch).map { meta, vcf, tbi -> tuple(meta, vcf, tbi) }
    }
    
    // Step 0: Conditionally apply SETGT if intersection is not performed
    if (!params.perform_intersection) {
        
        SETGT(vcfs_ch)
        ch_versions = ch_versions.mix(SETGT.out.versions)
        
        input_for_filtering = combineVcfIndex(SETGT.out.vcf, SETGT.out.tbi)
    } else {
        input_for_filtering = vcfs_ch
    }

    // Create empty channel for unused inputs
    empty_ch = Channel.value([])

    // Step  1: Keep only biallelic variants
    BCFTOOLS_VIEW_BIALLELIC(input_for_filtering, empty_ch, empty_ch, empty_ch)
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_BIALLELIC.out.versions)
    
    // Step  2: Apply minimum genotype quality (GQ) and depth (DP) filters
    BCFTOOLS_VIEW_QUAL_MIN(combineVcfIndex(BCFTOOLS_VIEW_BIALLELIC.out.vcf, BCFTOOLS_VIEW_BIALLELIC.out.tbi), empty_ch, empty_ch, empty_ch)
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_QUAL_MIN.out.versions)

    // Step  3: Exclude variants where all trio members are homozygous reference
    BCFTOOLS_VIEW_REFHOMO_EXCLUDE(combineVcfIndex(BCFTOOLS_VIEW_QUAL_MIN.out.vcf, BCFTOOLS_VIEW_QUAL_MIN.out.tbi), empty_ch, empty_ch, empty_ch)
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_REFHOMO_EXCLUDE.out.versions)

    // Step  4: Exclude problematic genomic regions (centromeres, segmental duplications and HLA/KIR)
    BCFTOOLS_VIEW_EXCL_ALL(combineVcfIndex(BCFTOOLS_VIEW_REFHOMO_EXCLUDE.out.vcf, BCFTOOLS_VIEW_REFHOMO_EXCLUDE.out.tbi), empty_ch, empty_ch, empty_ch)
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_EXCL_ALL.out.versions)

    // Step 5: Prepare final filtered VCFs with their indices
    final_vcfs = combineVcfIndex(BCFTOOLS_VIEW_EXCL_ALL.out.vcf, BCFTOOLS_VIEW_EXCL_ALL.out.tbi)
    
    emit:
    vcfs     = final_vcfs            // channel: [meta, vcf, tbi]
    versions = ch_versions           // channel: versions.yml
}