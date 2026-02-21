include { TABIX_TABIX                                            } from '../../../modules/nf-core/tabix/tabix/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_AUTOSOMES               } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_AUTOSOMES_GVCF          } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_ANNOTATE as BCFTOOLS_DELETE_ANNOTATIONS       } from '../../../modules/nf-core/bcftools/annotate/main'
include { BCFTOOLS_ANNOTATE as BCFTOOLS_DELETE_ANNOTATIONS_GVCF  } from '../../../modules/nf-core/bcftools/annotate/main'


workflow REMOVE_ANNOTATIONS {
    
    take:
    ch_samples    // channel: [val(meta), path(vcfs)]
    val_is_gvcf   // boolean: whether input files are GVCFs

    main:
    
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

    //
    // Combine VCF files with their corresponding index files
    //
    ch_indexed_vcfs = ch_individual_vcfs
        .join(TABIX_TABIX.out.index)
    
    //
    // Filter VCFs/GVCFs to keep only autosomal chromosomes (chr1-chr22)
    //
    if (val_is_gvcf) {
        BCFTOOLS_VIEW_AUTOSOMES_GVCF(
            ch_indexed_vcfs,
            [],
            [],
            []
        )
        ch_autosome_filtered = BCFTOOLS_VIEW_AUTOSOMES_GVCF.out.vcf
            .join(BCFTOOLS_VIEW_AUTOSOMES_GVCF.out.tbi)
    } else {
        BCFTOOLS_VIEW_AUTOSOMES(
            ch_indexed_vcfs,
            [],
            [],
            []
        )
        ch_autosome_filtered = BCFTOOLS_VIEW_AUTOSOMES.out.vcf
            .join(BCFTOOLS_VIEW_AUTOSOMES.out.tbi)
    }

    //
    // Prepare input for annotation removal
    //
    ch_annotate_input = ch_autosome_filtered
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
        
        ch_processed_vcfs = BCFTOOLS_DELETE_ANNOTATIONS_GVCF.out.vcf
            .join(BCFTOOLS_DELETE_ANNOTATIONS_GVCF.out.tbi)
    } else {
        BCFTOOLS_DELETE_ANNOTATIONS(
            ch_annotate_input,
            [],
            [],
            []
        )
        
        ch_processed_vcfs = BCFTOOLS_DELETE_ANNOTATIONS.out.vcf
            .join(BCFTOOLS_DELETE_ANNOTATIONS.out.tbi)
    }
    
    //
    // Regroup individual processed VCFs/GVCFs back into family trios
    //
    ch_regrouped = ch_processed_vcfs
        .map { meta, vcf, tbi ->
            [ meta.original_family_id, meta.role, meta, vcf, tbi ]
        }
        .groupTuple(by: 0)
        .map { family_id, roles, metas, vcfs, tbis ->
            // Reconstruct the original metadata
            def family_meta = [
                id   : family_id,
                proband_id : metas[0].proband_id,
                mother_id  : metas[0].mother_id,
                father_id  : metas[0].father_id,
                sv_p : metas[0].sv_p,
                sv_m : metas[0].sv_m,
                sv_f : metas[0].sv_f  
            ]
            
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

}