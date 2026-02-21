//
// Filter structural variants using BED regions and optionally filter ambiguous VAF
//
// This workflow processes samples with and without SV files, converts VCF SVs to BED format,
// merges overlapping regions, applies the mask to filter variants, and optionally filters ambiguous VAF.
//

include { CUSTOM_BEDCONCAT                               } from '../../../modules/local/custom/bedconcat/main'
include { BEDTOOLS_MERGE                                 } from '../../../modules/nf-core/bedtools/merge/main'
include { BCFTOOLS_VIEW_EXCLUDE as VIEW_MASK             } from '../../../modules/local/bcftools/view_exclude/main'
include { BCFTOOLS_QUERY                                 } from '../../../modules/nf-core/bcftools/query/main'
include { BCFTOOLS_VIEW as BCFTOOLS_FILTER_AMBIGUOUS_VAF } from '../../../modules/nf-core/bcftools/view/main'

workflow SV_MASK_BED {
    
    take:
    ch_vcfs    // channel: [val(meta), path(vcf), path(tbi)]
    val_apply_vaf_filter  // boolean: whether to filter ambiguous VAF variants 

    main:

    //
    // Expand metadata to include structural variant (SV) file paths
    //
    ch_sv_paths = ch_vcfs.map { meta, vcf, tbi ->
        [ meta, meta.sv_p, meta.sv_m, meta.sv_f, vcf, tbi ]
    }

    //
    // Split samples based on SV availability only
    //
    ch_mask_branches = ch_sv_paths.branch { meta, sv_p, sv_m, sv_f, vcf, tbi ->
        def has_sv = [sv_p, sv_m, sv_f].any { it != '-' && it != null }
        
        with_mask : has_sv
        no_mask   : !has_sv
    }

    //
    // Process samples with SV files
    //

    //
    // Flatten all SV paths (BED or VCF) into a single stream
    //
    ch_sv_files = ch_mask_branches.with_mask.flatMap { meta, sv_p, sv_m, sv_f, vcf, tbi ->
        [sv_p, sv_m, sv_f].findAll { it != '-' && it != null }.collect { sv_path ->
            [ meta, file(sv_path), vcf, tbi ]
        }
    }

    //
    // Split SV files by format (.bed vs .vcf.gz)
    //
    ch_bed_files = ch_sv_files.filter { meta, sv_file, vcf, tbi ->
        sv_file.name.endsWith('.bed')
    }
    
    ch_vcf_files = ch_sv_files.filter { meta, sv_file, vcf, tbi ->
        sv_file.name.endsWith('.vcf.gz')
    }
   
    //
    // Assign temporary metadata for VCFs (01, 02, 03) to prevent naming conflicts
    //
    ch_vcf_files_with_meta = ch_vcf_files.map { meta, sv_file, vcf, tbi ->
        def sv_paths = [meta.sv_p, meta.sv_m, meta.sv_f]
        def sv_identifier = String.format("%02d", sv_paths.indexOf(sv_file.toString()) + 1)
        def temp_meta = meta + [temp_id: "${meta.id}_${sv_identifier}"]
        [ temp_meta, sv_file, vcf, tbi, meta ]
    }

    //
    // Convert SV VCFs to BED format using bcftools query
    //
    BCFTOOLS_QUERY(
        ch_vcf_files_with_meta.map { temp_meta, sv_file, vcf, tbi, orig_meta -> 
            [ temp_meta, sv_file, [] ]
        },
        [],
        [],
        []
    )

    //
    // Reattach original metadata after conversion
    //
    ch_converted_beds = BCFTOOLS_QUERY.out.output
        .join(
            ch_vcf_files_with_meta.map { temp_meta, sv_file, vcf, tbi, orig_meta -> 
                [ temp_meta, orig_meta ]
            }
        )
        .map { temp_meta, bed_file, orig_meta -> 
            [ orig_meta, bed_file ]
        }

    //
    // Combine original BEDs with converted BEDs (only SV files now)
    //
    ch_all_bed_files = ch_bed_files
        .map { meta, sv_file, vcf, tbi -> 
            [ meta, sv_file ]
        }
        .mix(ch_converted_beds)

    //
    // Group all BEDs per sample
    //
    ch_beds_grouped = ch_all_bed_files.groupTuple(by: 0)

    //
    // Get VCFs for samples that have SV masks
    //
    ch_vcfs_with_mask = ch_mask_branches.with_mask
        .map { meta, sv_p, sv_m, sv_f, vcf, tbi -> 
            [ meta, vcf, tbi ]
        }

    //
    // Link grouped BEDs to corresponding VCFs
    //
    ch_beds_with_vcf = ch_vcfs_with_mask
        .join(ch_beds_grouped)
        .map { meta, vcf, tbi, bed_files ->
            [ meta, bed_files, vcf, tbi ]
        }

    //
    // Concatenate multiple BED files per sample into one
    //
    CUSTOM_BEDCONCAT(
        ch_beds_with_vcf.map { meta, beds, vcf, tbi -> 
            [ meta, beds ]
        }
    )
    
    //
    // Merge overlapping BED regions into a unified mask
    //
    BEDTOOLS_MERGE(CUSTOM_BEDCONCAT.out.bed)

    //
    // Associate merged BED mask with the sample's VCF
    //
    ch_mask_combined = ch_beds_with_vcf
        .map { meta, beds, vcf, tbi -> 
            [ meta, vcf, tbi ]
        }
        .join(BEDTOOLS_MERGE.out.bed)
        .map { meta, vcf, tbi, bed -> 
            [ meta, vcf, tbi, bed ]
        }
    
    //
    // Apply BED mask to VCF using bcftools view
    //
    VIEW_MASK(
        ch_mask_combined.map { meta, vcf, tbi, bed -> [ meta, vcf, tbi ] },
        ch_mask_combined.map { meta, vcf, tbi, bed -> bed },
        [],
        []
    )

    //
    // Join filtered VCFs with their indices
    //
    ch_with_mask_joined = VIEW_MASK.out.vcf
        .join(VIEW_MASK.out.tbi)

    //
    // Process samples without any SV mask files (pass through unmodified)
    //
    ch_no_mask_vcf = ch_mask_branches.no_mask
        .map { meta, sv_p, sv_m, sv_f, vcf, tbi -> 
            [ meta, vcf, tbi ]
        }

    //
    // Merge SV-processed and unprocessed results
    //
    ch_sv_filtered_vcfs = ch_with_mask_joined.mix(ch_no_mask_vcf)

    // Apply VAF ambiguous filtering if requested
    if (val_apply_vaf_filter) {
        BCFTOOLS_FILTER_AMBIGUOUS_VAF(
            ch_sv_filtered_vcfs,
            [],
            [],
            []
        )
        
        ch_final_vcfs = BCFTOOLS_FILTER_AMBIGUOUS_VAF.out.vcf
            .join(BCFTOOLS_FILTER_AMBIGUOUS_VAF.out.tbi)
    } else {
        ch_final_vcfs = ch_sv_filtered_vcfs
    }

    emit:
    vcf      = ch_final_vcfs  // channel: [val(meta), path(vcf), path(tbi)]

}