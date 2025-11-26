//
// Filter autosomes, remove unused annotations from individual VCFs, and regroup by family
//

include { TABIX_TABIX } from '../../../modules/nf-core/tabix/tabix/main'
include { BCFTOOLS_VIEW as BCFTOOLS_VIEW_AUTOSOMES } from '../../../modules/nf-core/bcftools/view/main'
include { BCFTOOLS_ANNOTATE as BCFTOOLS_DELETE_ANNOTATIONS } from '../../../modules/nf-core/bcftools/annotate/main'
include { BCFTOOLS_ANNOTATE as BCFTOOLS_DELETE_ANNOTATIONS_GVCF } from '../../../modules/nf-core/bcftools/annotate/main'

workflow REMOVE_ANNOTATIONS {
    
    take:
    samples_ch    // channel: [meta, vcfs] 
    
    main:
    ch_versions = Channel.empty()
    
    // Step 1: Flatten family trios into individual VCF files
    individual_vcfs_ch = samples_ch.flatMap { meta, vcfs ->  
        def individuals = []
        def roles = ['01', '02', '03'] // Role codes: 01=Proband, 02=Mother, 03=Father
        
        vcfs.eachWithIndex { vcf, idx ->
            def individual_meta = meta.clone()
            individual_meta.role = roles[idx]
            individual_meta.original_family_id = meta.id
            individual_meta.id = "${meta.id}_${roles[idx]}"
            
            individuals << tuple(individual_meta, vcf)
        }
        return individuals
    }

    // Step 2: Index all VCF files with tabix 
    TABIX_TABIX(individual_vcfs_ch)
    ch_versions = ch_versions.mix(TABIX_TABIX.out.versions)

    // Combine VCF files with their corresponding index files
    indexed_vcfs_ch = individual_vcfs_ch
        .map { meta, vcf -> tuple(meta, vcf) }  
        .join(TABIX_TABIX.out.tbi)             
        .map { meta, vcf, tbi ->
            tuple(meta, vcf, tbi)
        }
    
    // Step 3: Filter VCFs to keep only autosomal chromosomes (chr1-chr22)
    BCFTOOLS_VIEW_AUTOSOMES(indexed_vcfs_ch, [], [], [])
    ch_versions = ch_versions.mix(BCFTOOLS_VIEW_AUTOSOMES.out.versions)

    // Prepare input for annotation removal
    annotate_input = BCFTOOLS_VIEW_AUTOSOMES.out.vcf
        .join(BCFTOOLS_VIEW_AUTOSOMES.out.tbi)
        .map { meta, vcf, tbi ->
            tuple(meta, vcf, tbi, [], [])
        }

    // Step 6: Remove unused annotations from VCF/GVCF files
    if (params.is_gvcf) {
        BCFTOOLS_DELETE_ANNOTATIONS_GVCF(annotate_input, [], [], [])
        ch_versions = ch_versions.mix(BCFTOOLS_DELETE_ANNOTATIONS_GVCF.out.versions)
        
        processed_vcfs_ch = BCFTOOLS_DELETE_ANNOTATIONS_GVCF.out.vcf
            .join(BCFTOOLS_DELETE_ANNOTATIONS_GVCF.out.tbi)
    } else {
        BCFTOOLS_DELETE_ANNOTATIONS(annotate_input, [], [], [])
        ch_versions = ch_versions.mix(BCFTOOLS_DELETE_ANNOTATIONS.out.versions)
        
        processed_vcfs_ch = BCFTOOLS_DELETE_ANNOTATIONS.out.vcf
            .join(BCFTOOLS_DELETE_ANNOTATIONS.out.tbi)
    }
    
    // Step 7: Regroup individual processed VCFs back into family trios
    // This maintains the original family structure for downstream trio analysis
    regrouped_ch = processed_vcfs_ch
        .map { meta, vcf, tbi ->
            tuple(meta.original_family_id, meta.role, meta, vcf, tbi)
        }
        .groupTuple(by: 0)  // Group by original family ID
        .map { family_id, roles, metas, vcfs, tbis ->
            // Reconstruct the original metadata
            def family_meta = [
                id: family_id,
                sv_p: metas[0].sv_p,
                sv_m: metas[0].sv_m,
                sv_f: metas[0].sv_f  
            ]
            
            // Sort VCFs and indices by role to maintain order (proband, mother, father)
            def role_order = ['01', '02', '03']
            def sorted_data = [roles, vcfs, tbis].transpose().sort { 
                role_order.indexOf(it[0])
            }
            def sorted_vcfs = sorted_data.collect { it[1] }
            def sorted_tbis = sorted_data.collect { it[2] }
            
            tuple(family_meta, sorted_vcfs, sorted_tbis)
        }
    
    emit:
    vcfs     = regrouped_ch           // channel: [meta, vcfs, tbis]
    versions = ch_versions            // channel: versions.yml
}