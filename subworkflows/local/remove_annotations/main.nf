
include { TABIX_TABIX                                            } from '../../../modules/nf-core/tabix/tabix/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_AUTOSOMES               } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_ANNOTATE as BCFTOOLS_DELETE_ANNOTATIONS       } from '../../../modules/nf-core/bcftools/annotate/main'
include { BCFTOOLS_ANNOTATE as BCFTOOLS_DELETE_ANNOTATIONS_GVCF  } from '../../../modules/nf-core/bcftools/annotate/main'
include { BCFTOOLS_VIEW as BCFTOOLS_EXTRACT_AMBIGUOUS_VAF        } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_QUERY as BCFTOOLS_QUERY_VAF_TO_BED            } from '../../../modules/nf-core/bcftools/query/main'


workflow REMOVE_ANNOTATIONS {
    
    take:
    ch_samples    // channel: [val(meta), path(vcfs)]
    val_is_gvcf   // boolean: whether input files are GVCFs
    val_apply_vaf_filter // boolean: whether to detect ambiguous VAF variants

    main:
    ch_versions = Channel.empty()
    
    //
    // Flatten family trios into individual VCF files
    //
    ch_individual_vcfs = ch_samples.flatMap { meta, vcfs ->  
        def individuals = []
        def roles = ['01', '02', '03'] // Role codes: 01=Proband, 02=Mother, 03=Father
        
        vcfs.eachWithIndex { vcf, idx ->
            def individual_meta = meta.clone()
            individual_meta.role = roles[idx]
            individual_meta.original_family_id = meta.id
            individual_meta.id = "${meta.id}_${roles[idx]}"
            
            individuals << [ individual_meta, vcf ]
        }
        return individuals
    }

    //
    // Index all VCF/GVCF files with tabix
    //
    TABIX_TABIX(ch_individual_vcfs)
    ch_versions = ch_versions.mix(TABIX_TABIX.out.versions)

    //
    // Combine VCF files with their corresponding index files
    //
    ch_indexed_vcfs = ch_individual_vcfs
        .join(TABIX_TABIX.out.tbi)
    
    //
    // Filter VCFs/GVCFs to keep only autosomal chromosomes (chr1-chr22)
    //
    BCFTOOLS_VIEW_AUTOSOMES(
        ch_indexed_vcfs,
        [],
        [],
        []
    )
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_AUTOSOMES.out.versions)

    //
    // Prepare input for annotation removal
    //
    ch_annotate_input = BCFTOOLS_VIEW_AUTOSOMES.out.vcf
        .join(BCFTOOLS_VIEW_AUTOSOMES.out.tbi)
        .map { meta, vcf, tbi ->
            [ meta, vcf, tbi, [], [] ]
        }

    //
    // Remove unused annotations from VCF/GVCF files
    //
    if (val_is_gvcf) {
        BCFTOOLS_DELETE_ANNOTATIONS_GVCF(
            ch_annotate_input,
            [],
            [],
            []
        )
        ch_versions = ch_versions.mix(BCFTOOLS_DELETE_ANNOTATIONS_GVCF.out.versions)
        
        ch_processed_vcfs = BCFTOOLS_DELETE_ANNOTATIONS_GVCF.out.vcf
            .join(BCFTOOLS_DELETE_ANNOTATIONS_GVCF.out.tbi)
    } else {
        BCFTOOLS_DELETE_ANNOTATIONS(
            ch_annotate_input,
            [],
            [],
            []
        )
        ch_versions = ch_versions.mix(BCFTOOLS_DELETE_ANNOTATIONS.out.versions)
        
        ch_processed_vcfs = BCFTOOLS_DELETE_ANNOTATIONS.out.vcf
            .join(BCFTOOLS_DELETE_ANNOTATIONS.out.tbi)
    }
    
    //
    // Extract variants with ambiguous VAF per individual
    //
    if (val_apply_vaf_filter) {
        BCFTOOLS_EXTRACT_AMBIGUOUS_VAF(
            ch_processed_vcfs,
            [],
            [],
            []
        )
        ch_versions = ch_versions.mix(BCFTOOLS_EXTRACT_AMBIGUOUS_VAF.out.versions)
        
        //
        // Convert ambiguous variants to BED format
        //
        BCFTOOLS_QUERY_VAF_TO_BED(
            BCFTOOLS_EXTRACT_AMBIGUOUS_VAF.out.vcf
                .join(BCFTOOLS_EXTRACT_AMBIGUOUS_VAF.out.tbi),
            [],
            [],
            []
        )
        ch_versions = ch_versions.mix(BCFTOOLS_QUERY_VAF_TO_BED.out.versions)
        
        //
        // Filter out empty BED files and store non-empty ones in metadata
        //
        ch_non_empty_beds = BCFTOOLS_QUERY_VAF_TO_BED.out.output
            .filter { meta, bed ->
                bed.size() > 0
            }
        
        ch_processed_with_vaf_bed = ch_processed_vcfs
            .join(ch_non_empty_beds, remainder: true)
            .map { meta, vcf, tbi, bed ->
                def meta_with_bed = meta.clone()
                meta_with_bed.vaf_bed = bed ?: null
                [ meta_with_bed, vcf, tbi ]
            }
    } else {
        ch_processed_with_vaf_bed = ch_processed_vcfs
    }
    
    //
    // Regroup individual processed VCFs/GVCFs back into family trios
    //
    ch_regrouped = ch_processed_with_vaf_bed
        .map { meta, vcf, tbi ->
            [ meta.original_family_id, meta.role, meta, vcf, tbi ]
        }
        .groupTuple(by: 0)
        .map { family_id, roles, metas, vcfs, tbis ->
            // Reconstruct the original metadata
            def family_meta = [
                id   : family_id,
                sv_p : metas[0].sv_p,
                sv_m : metas[0].sv_m,
                sv_f : metas[0].sv_f  
            ]
            
            // Collect VAF BED files if they exist
            if (val_apply_vaf_filter) {
                family_meta.vaf_bed_p = metas.find { it.role == '01' }?.vaf_bed ?: null
                family_meta.vaf_bed_m = metas.find { it.role == '02' }?.vaf_bed ?: null
                family_meta.vaf_bed_f = metas.find { it.role == '03' }?.vaf_bed ?: null
            }
            
            // Sort VCFs and indices by role to maintain order (proband, mother, father)
            def role_order = ['01', '02', '03']
            def sorted_data = [roles, vcfs, tbis].transpose().sort { 
                role_order.indexOf(it[0])
            }
            def sorted_vcfs = sorted_data.collect { it[1] }
            def sorted_tbis = sorted_data.collect { it[2] }
            
            [ family_meta, sorted_vcfs, sorted_tbis ]
        }
    
    emit:
    vcf      = ch_regrouped  // channel: [val(meta), path(vcfs), path(tbis)]
    versions = ch_versions   // channel: [path(versions.yml)]
}