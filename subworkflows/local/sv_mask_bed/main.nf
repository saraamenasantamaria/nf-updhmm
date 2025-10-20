//
// Filter structural variants using BED regions
//
// Steps:
//   1. Split samples into those with SVs and those without.
//   2. For samples with SVs: detect SV file type (.bed vs .vcf.gz).
//   3. Convert .vcf.gz SV files to BED format when needed.
//   4. Concatenate and merge all BEDs per sample to create a unified region mask.
//   5. Apply the merged mask to the input VCF using bcftools view.
//   6. Pass through unmodified VCFs for samples without SVs.
//   7. Combine all filtered and unfiltered outputs into a single channel.
//

include { CONCAT_BED } from '../../../modules/local/concat_bed/main'
include { BEDTOOLS_MERGE } from '../../../modules/nf-core/bedtools/merge/main'
include { BCFTOOLS_VIEW as VIEW_MASK } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_QUERY } from '../../../modules/nf-core/bcftools/query/main'

workflow SV_MASK_BED {
    take:
    vcfs_ch    // channel: [meta, vcf, tbi]

    main:

    ch_versions = Channel.empty()

    // Step 1: Expand metadata to include structural variant (SV) file paths
    sv_paths_ch = vcfs_ch.map { meta, vcf, tbi ->
        tuple(meta, meta.sv_p, meta.sv_m, meta.sv_f, vcf, tbi) }

    // Step 2: Split samples based on SV availability
    sv_branches = sv_paths_ch.branch { meta, sv_p, sv_m, sv_f, vcf, tbi ->
        with_sv: [sv_p, sv_m, sv_f].any { it != '-' }
        no_sv: [sv_p, sv_m, sv_f].every { it == '-' } }

    // ------------------------------
    // Process samples with SVs files
    // ------------------------------

    // Step 3: Flatten all SV paths (BED or VCF) into a single stream
    sv_files_ch = sv_branches.with_sv.flatMap { meta, sv_p, sv_m, sv_f, vcf, tbi ->
        [sv_p, sv_m, sv_f].findAll { it != '-' && it != null }.collect { sv_path ->
            tuple(meta, file(sv_path), vcf, tbi) } }

    // Step 4: Split SV files by format (.bed vs .vcf.gz)
    bed_files_ch = sv_files_ch.filter { meta, sv_file, vcf, tbi ->
        sv_file.name.endsWith('.bed') }
    
    vcf_files_ch = sv_files_ch.filter { meta, sv_file, vcf, tbi ->
        sv_file.name.endsWith('.vcf.gz') }
   
    // Step 5: Assign temporary metadata for VCFs (01, 02, 03) to prevent naming conflicts
    vcf_files_with_meta_ch = vcf_files_ch.map { meta, sv_file, vcf, tbi ->
        def sv_paths = [meta.sv_p, meta.sv_m, meta.sv_f]
        def sv_identifier = String.format("%02d", sv_paths.indexOf(sv_file.toString()) + 1)
        def temp_meta = meta + [temp_id: "${meta.id}_${sv_identifier}"]
        tuple(temp_meta, sv_file, vcf, tbi, meta) }

    // Step 6: Convert SV VCFs to BED format using bcftools query
    BCFTOOLS_QUERY(
        vcf_files_with_meta_ch.map { temp_meta, sv_file, vcf, tbi, orig_meta -> 
            tuple(temp_meta, sv_file, []) }, [], [], [])      
    ch_versions = ch_versions.mix(BCFTOOLS_QUERY.out.versions) 

    // Step 7: Reattach original metadata after conversion
    converted_beds_ch = BCFTOOLS_QUERY.out.output
        .join(
            vcf_files_with_meta_ch.map { temp_meta, sv_file, vcf, tbi, orig_meta -> 
                tuple(temp_meta, orig_meta) }
        ).map { temp_meta, bed_file, orig_meta -> 
            tuple(orig_meta, bed_file) }

    // Step 8: Combine original BEDs with converted BEDs
    all_bed_files_ch = bed_files_ch
        .map { meta, sv_file, vcf, tbi -> 
            tuple(meta, sv_file) 
        }.mix(converted_beds_ch)

    // Step 9: Group all BEDs per sample
    beds_grouped_ch = all_bed_files_ch.groupTuple(by: 0)

    // Step 10: Link grouped BEDs to corresponding VCFs
    beds_with_vcf_ch = vcfs_ch
        .map { meta, vcf, tbi -> 
            tuple(meta, vcf, tbi) }
        .join(beds_grouped_ch)
        .map { meta, vcf, tbi, bed_files ->
            tuple(meta, bed_files, vcf, tbi) }

    // Step 11: Concatenate multiple BED files per sample into one
    CONCAT_BED(
        beds_with_vcf_ch.map { meta, beds, vcf, tbi -> 
            tuple(meta, beds) }
    )
    
    // Step 12: Merge overlapping BED regions into a unified mask
    BEDTOOLS_MERGE(CONCAT_BED.out.bed)
    ch_versions = ch_versions.mix(CONCAT_BED.out.versions)
    
    merged_bed_ch = BEDTOOLS_MERGE.out.bed 
    ch_versions = ch_versions.mix(BEDTOOLS_MERGE.out.versions)

    // Step 13: Associate merged BED mask with the samples VCF
    mask_combined_ch = beds_with_vcf_ch
        .map { meta, beds, vcf, tbi -> 
            tuple(meta, vcf, tbi) }
        .join(
            merged_bed_ch.map { meta, bed -> 
                tuple(meta, bed) }
        )
        .map { meta, vcf, tbi, bed -> 
            tuple(meta, vcf, tbi, bed) }

    // Step 14: Apply BED mask to VCF using bcftools view
    VIEW_MASK(
        mask_combined_ch.map { meta, vcf, tbi, bed -> tuple(meta, vcf, tbi) },
        mask_combined_ch.map { meta, vcf, tbi, bed -> bed }, [], []
    )

    with_sv_joined_ch = VIEW_MASK.out.vcf
        .join(VIEW_MASK.out.tbi)
        .map { meta, vcf, tbi -> tuple(meta, vcf, tbi) }
    
    ch_versions = ch_versions.mix(VIEW_MASK.out.versions)

    // ---------------------------------
    // Process samples without SVs files
    // ---------------------------------

    no_sv_vcf_ch = sv_branches.no_sv
        .map { meta, sv_p, sv_m, sv_f, vcf, tbi -> 
            tuple(meta, vcf, tbi) 
        }

    // Step 16: Merge processed and unprocessed results
    all_vcfs_ch = with_sv_joined_ch.mix(no_sv_vcf_ch)

    emit:
    vcfs     = all_vcfs_ch
    versions = ch_versions
}