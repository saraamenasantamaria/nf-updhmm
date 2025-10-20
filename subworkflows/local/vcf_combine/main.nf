//
// Perform VCF intersection and merge operations
//
// If `val_perform_intersection` is true, only shared variants among trio members are retained (intersection mode).
// Otherwise, all variants from the trio are combined directly (union mode).
//

include { BCFTOOLS_ISEC  } from '../../../modules/nf-core/bcftools/isec/main'
include { BCFTOOLS_MERGE } from '../../../modules/nf-core/bcftools/merge/main'

workflow VCF_COMBINE {
    
    take:
    ch_vcfs    // channel: [val(meta), path(vcfs), path(tbis)]
    val_perform_intersection  // boolean: whether to perform intersection
    
    main:
    ch_versions = Channel.empty()

    //
    // Optionally perform VCF intersection
    // If val_perform_intersection is enabled, extract only variants shared among all trio members
    //
    if (val_perform_intersection) {
        
        BCFTOOLS_ISEC(ch_vcfs)
        ch_versions = ch_versions.mix(BCFTOOLS_ISEC.out.versions)

        ch_merge_input = BCFTOOLS_ISEC.out.results
            .map { meta, dir ->
                def vcfs = file("${dir}/000*.vcf.gz")
                def tbis = file("${dir}/*.tbi")
                [ meta, vcfs, tbis ]
            }
    } else {
        //
        // Skip intersection and use original VCFs directly
        //
        ch_merge_input = ch_vcfs
    }

    //
    // Prepare empty channels for optional BCFTOOLS_MERGE inputs
    //
    ch_fasta        = Channel.value([ [:], [] ])
    ch_fasta_fai    = Channel.value([ [:], [] ])
    ch_bed_regions  = Channel.value([ [:], [] ])

    //
    // Merge VCFs (either intersected or original)
    //
    BCFTOOLS_MERGE(
        ch_merge_input,
        ch_fasta,
        ch_fasta_fai,
        ch_bed_regions
    )
    ch_versions = ch_versions.mix(BCFTOOLS_MERGE.out.versions)

    //
    // Join merged VCFs with their index files
    //
    ch_merged_vcfs = BCFTOOLS_MERGE.out.vcf
        .join(BCFTOOLS_MERGE.out.index)
    
    emit:
    vcf      = ch_merged_vcfs  // channel: [val(meta), path(vcf), path(tbi)]
    versions = ch_versions     // channel: [path(versions.yml)]
}