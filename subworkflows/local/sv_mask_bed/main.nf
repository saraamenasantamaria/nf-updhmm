//
// Filter structural variants using BED regions
//
// This workflow processes samples with and without SV files, converts VCF SVs to BED format,
// merges overlapping regions, and applies the mask to filter variants.
//

include { CUSTOM_BEDCONCAT                 } from '../../../modules/local/custom/bedconcat/main'
include { BEDTOOLS_MERGE             } from '../../../modules/nf-core/bedtools/merge/main'
include { BCFTOOLS_VIEW as VIEW_MASK } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_QUERY             } from '../../../modules/nf-core/bcftools/query/main'

workflow SV_MASK_BED {
    
    take:
    ch_vcfs    // channel: [val(meta), path(vcf), path(tbi)]

    main:
    ch_versions = Channel.empty()

    //
    // Expand metadata to include structural variant (SV) file paths
    //
    ch_sv_paths = ch_vcfs.map { meta, vcf, tbi ->
        [ meta, meta.sv_p, meta.sv_m, meta.sv_f, vcf, tbi ]
    }

    //
    // Split samples based on SV or VAF availability
    //
    ch_mask_branches = ch_sv_paths.branch { meta, sv_p, sv_m, sv_f, vcf, tbi ->
        def has_sv = [sv_p, sv_m, sv_f].any { it != '-' && it != null }
        def has_vaf = (meta.containsKey('vaf_bed_p') && meta.vaf_bed_p != null) ||
                      (meta.containsKey('vaf_bed_m') && meta.vaf_bed_m != null) ||
                      (meta.containsKey('vaf_bed_f') && meta.vaf_bed_f != null)
        
        with_mask : has_sv || has_vaf
        no_mask   : !has_sv && !has_vaf
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
    ch_versions = ch_versions.mix(BCFTOOLS_QUERY.out.versions)

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
    // Combine original BEDs with converted BEDs
    //
    ch_all_bed_files = ch_bed_files
        .map { meta, sv_file, vcf, tbi -> 
            [ meta, sv_file ]
        }
        .mix(ch_converted_beds)
    
    // 
    // Add VAF ambiguous BED files if they exist in metadata
    // 
    ch_vaf_beds = ch_mask_branches.with_mask
        .map { meta, sv_p, sv_m, sv_f, vcf, tbi -> meta }
        .flatMap { meta ->
            def vaf_beds = []
            
            // Collect VAF BED files from metadata if they exist
            if (meta.containsKey('vaf_bed_p') && meta.vaf_bed_p != null) {
                vaf_beds << [ meta, meta.vaf_bed_p ]
            }
            if (meta.containsKey('vaf_bed_m') && meta.vaf_bed_m != null) {
                vaf_beds << [ meta, meta.vaf_bed_m ]
            }
            if (meta.containsKey('vaf_bed_f') && meta.vaf_bed_f != null) {
                vaf_beds << [ meta, meta.vaf_bed_f ]
            }
            
            return vaf_beds
        }
    
    //
    // Combine SV BEDs with VAF BEDs
    //
    ch_all_bed_files = ch_all_bed_files.mix(ch_vaf_beds)

    //
    // Group all BEDs per sample
    //
    ch_beds_grouped = ch_all_bed_files.groupTuple(by: 0)

    //
    // Get VCFs for samples that have masks (SV or VAF)
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
    ch_versions = ch_versions.mix(CUSTOM_BEDCONCAT.out.versions)
    
    //
    // Merge overlapping BED regions into a unified mask
    //
    BEDTOOLS_MERGE(CUSTOM_BEDCONCAT.out.bed)
    ch_versions = ch_versions.mix(BEDTOOLS_MERGE.out.versions)

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
    ch_versions = ch_versions.mix(VIEW_MASK.out.versions)

    //
    // Join filtered VCFs with their indices
    //
    ch_with_mask_joined = VIEW_MASK.out.vcf
        .join(VIEW_MASK.out.tbi)

    //
    // Process samples without any mask files (pass through unmodified)
    //
    ch_no_mask_vcf = ch_mask_branches.no_mask
        .map { meta, sv_p, sv_m, sv_f, vcf, tbi -> 
            [ meta, vcf, tbi ]
        }

    //
    // Merge processed and unprocessed results
    //
    ch_all_vcfs = ch_with_mask_joined.mix(ch_no_mask_vcf)

    emit:
    vcf      = ch_all_vcfs  // channel: [val(meta), path(vcf), path(tbi)]
    versions = ch_versions  // channel: [path(versions.yml)]
}