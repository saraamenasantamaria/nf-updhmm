//
// Apply hard filters to produce the final preprocessed VCF per family
//
// This workflow applies sequential filters to VCFs to ensure high-confidence variants.
// Filters include:
//   1) Keep only biallelic sites
//   2) Apply minimum genotype quality (GQ) and depth (DP) thresholds
//   3) Exclude variants where all trio members are homozygous reference (0/0 or 0|0)
//   4) Exclude problematic genomic regions (centromeres, segmental duplications, HLA/KIR)
//
// Optional preprocessing (conditional):
//   - SETGT: Set missing genotypes (applied when intersection is skipped)
//   - SETGT_VAF: Correct genotypes by VAF thresholds (optional correction)
//

include { BCFTOOLS_SETGT                              } from '../../../modules/local/bcftools/setgt/main'
include { BCFTOOLS_SETGT_VAF                          } from '../../../modules/local/bcftools/setgt_vaf/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_FILTER_ALL   } from '../../../modules/nf-core/bcftools/view/main'


workflow FILTER_LOWCONF {
    
    take:
    ch_vcfs                   // channel: [val(meta), path(vcf), path(tbi)]
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
    // Conditionally apply BCFTOOLS_SETGT_VAF for VAF-based genotype correction
    //
    if (val_apply_vaf_correction) {
        BCFTOOLS_SETGT_VAF(ch_input_for_filtering)
        
        ch_versions = ch_versions.mix(BCFTOOLS_SETGT_VAF.out.versions)
        
        ch_input_for_filtering = BCFTOOLS_SETGT_VAF.out.vcf
            .join(BCFTOOLS_SETGT_VAF.out.tbi)
    }
    
    
    //
    // Prepare excluded regions BED file
    //
    def excluded_regions_bed = params.excluded_regions_bed ? 
        file(params.excluded_regions_bed, checkIfExists: true) :
        file("${projectDir}/assets/${params.genome_build}_excluded_regions.bed", checkIfExists: true)
    
    ch_excluded_regions = Channel.value(excluded_regions_bed)
    
    
    //
    // Apply all filters
    // 
    BCFTOOLS_VIEW_FILTER_ALL(
        ch_input_for_filtering,
        ch_excluded_regions,
        [],
        []
    )
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_FILTER_ALL.out.versions)


    //
    // Prepare final filtered VCFs with their indices
    //
    ch_final_vcfs = BCFTOOLS_VIEW_FILTER_ALL.out.vcf
        .join(BCFTOOLS_VIEW_FILTER_ALL.out.tbi)
    
    emit:
    vcf      = ch_final_vcfs  // channel: [val(meta), path(vcf), path(tbi)]
    versions = ch_versions    // channel: [path(versions.yml)]
}