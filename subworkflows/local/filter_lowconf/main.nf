//
// Apply hard filters to produce the final preprocessed VCF per family
//
// This workflow applies sequential filters to VCFs to ensure high-confidence variants.
// Filters include:
//   1) Keep only biallelic sites
//   2) Apply minimum genotype quality (GQ) and depth (DP) filters
//   3) Exclude variants where all trio members are homozygous reference (0/0 or 0|0)
//   4) Exclude problematic genomic regions (centromeres, segmental duplications, HLA/KIR)
//
// Notes:
//   - BCFTOOLS_SETGT is applied conditionally if val_perform_intersection is false.
//   - All bcftools arguments are configured via conf/modules.config.
//

include { BCFTOOLS_SETGT                                     } from '../../../modules/local/bcftools/setgt/main'
include { BCFTOOLS_SETGT_VAF                                 } from '../../../modules/local/bcftools/setgt_vaf/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_BIALLELIC           } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_QUAL_MIN            } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_REFHOMO_EXCLUDE     } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_EXCL_ALL            } from '../../../modules/nf-core/bcftools/view/main'


workflow FILTER_LOWCONF {
    
    take:
    ch_vcfs    // channel: [val(meta), path(vcf), path(tbi)]
    val_perform_intersection  // boolean: whether to perform intersection
    val_apply_vaf_correction  // boolean: whether to apply VAF-based GT correction
    
    main:
    ch_versions = Channel.empty()
    
    //
    // Conditionally apply BCFTOOLS_SETGT if intersection is not performed
    //
    if (!val_perform_intersection) {
        
        BCFTOOLS_SETGT(ch_vcfs)
        ch_versions = ch_versions.mix(BCFTOOLS_SETGT.out.versions)
        
        ch_input_for_filtering = BCFTOOLS_SETGT.out.vcf
            .join(BCFTOOLS_SETGT.out.tbi)
    } else {
        ch_input_for_filtering = ch_vcfs
    }
    
    //
    // Correct genotypes based on clear VAF thresholds
    // Note: Ambiguous variants (0.15-0.30, 0.70-0.85) were already removed in SV_MASK_BED
    //
    
    if (val_apply_vaf_correction) {
        //
        // Correct remaining variants with clear VAF but wrong GT:
        // 0/1 with VAF < 0.15 -> 0/0 (clearly homozygous reference)
        // 0/1 with VAF > 0.85 -> 1/1 (clearly homozygous alternate)
        //
        BCFTOOLS_SETGT_VAF(ch_input_for_filtering)
        ch_versions = ch_versions.mix(BCFTOOLS_SETGT_VAF.out.versions)
        ch_input_for_filtering = BCFTOOLS_SETGT_VAF.out.vcf
            .join(BCFTOOLS_SETGT_VAF.out.tbi)
    }

    //
    // Prepare empty channel for unused inputs
    //
    ch_empty = Channel.value([])

    //
    // Keep only biallelic variants
    //
    BCFTOOLS_VIEW_BIALLELIC(
        ch_input_for_filtering,
        ch_empty,
        ch_empty,
        ch_empty
    )
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_BIALLELIC.out.versions)
    
    //
    // Apply minimum genotype quality (GQ) and depth (DP) filters
    //
    BCFTOOLS_VIEW_QUAL_MIN(
        BCFTOOLS_VIEW_BIALLELIC.out.vcf.join(BCFTOOLS_VIEW_BIALLELIC.out.tbi),
        ch_empty,
        ch_empty,
        ch_empty
    )
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_QUAL_MIN.out.versions)

    //
    // Exclude variants where all trio members are homozygous reference
    //
    BCFTOOLS_VIEW_REFHOMO_EXCLUDE(
        BCFTOOLS_VIEW_QUAL_MIN.out.vcf.join(BCFTOOLS_VIEW_QUAL_MIN.out.tbi),
        ch_empty,
        ch_empty,
        ch_empty
    )
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_REFHOMO_EXCLUDE.out.versions)

    //
    // Exclude problematic genomic regions (centromeres, segmental duplications and HLA/KIR)
    //
    BCFTOOLS_VIEW_EXCL_ALL(
        BCFTOOLS_VIEW_REFHOMO_EXCLUDE.out.vcf.join(BCFTOOLS_VIEW_REFHOMO_EXCLUDE.out.tbi),
        ch_empty,
        ch_empty,
        ch_empty
    )
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_EXCL_ALL.out.versions)

    //
    // Prepare final filtered VCFs with their indices
    //
    ch_final_vcfs = BCFTOOLS_VIEW_EXCL_ALL.out.vcf
        .join(BCFTOOLS_VIEW_EXCL_ALL.out.tbi)
    
    emit:
    vcf      = ch_final_vcfs  // channel: [val(meta), path(vcf), path(tbi)]
    versions = ch_versions    // channel: [path(versions.yml)]
}