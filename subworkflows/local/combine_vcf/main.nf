//
// Perform VCF intersection and merge operations
//
// If `params.perform_intersection` is true, only shared variants among trio members are retained (intersection mode).
// Otherwise, all variants from the trio are combined directly (union mode).
//

include { BCFTOOLS_ISEC  } from '../../../modules/nf-core/bcftools/isec/main'
include { BCFTOOLS_MERGE } from '../../../modules/nf-core/bcftools/merge/main'

workflow COMBINE_VCF {
    
    take:
    vcfs_ch    // channel: [meta, vcfs, tbis]
    
    main:
    ch_versions = Channel.empty()

    // Step 1: Optionally perform VCF intersection
    // If `perform_intersection` is enabled, extract only variants shared among all trio members
    if (params.perform_intersection) {
        
        // Run intersection across trio VCFs
        BCFTOOLS_ISEC(vcfs_ch)
        ch_versions = ch_versions.mix(BCFTOOLS_ISEC.out.versions)

        merge_input_ch = BCFTOOLS_ISEC.out.results.map { meta, dir ->
            def vcfs = file("${dir}/000*.vcf.gz")
            def tbis = file("${dir}/*.tbi")
            tuple(meta, vcfs, tbis)
        }
    } else {
        // Step 1 (alternative): Skip intersection and use original VCFs directly
        merge_input_ch = vcfs_ch
    }

    empty_tuple_ch = Channel.value([[:], []])

    // Step 2: Merge VCFs (either intersected or original)
    BCFTOOLS_MERGE(merge_input_ch, empty_tuple_ch, empty_tuple_ch, empty_tuple_ch)
    ch_versions = ch_versions.mix(BCFTOOLS_MERGE.out.versions)

    // Step 3: Join merged VCFs with their index files and format the output
    merged_vcfs_ch = BCFTOOLS_MERGE.out.vcf
        .join(BCFTOOLS_MERGE.out.index)
        .map { meta, vcf, tbi ->
            tuple(meta, vcf, tbi)
        }
    
    emit:
    vcfs     = merged_vcfs_ch    // channel: [meta, vcf, tbi]
    versions = ch_versions       // channel: versions.yml

}

 