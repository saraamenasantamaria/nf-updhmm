//
// Preprocess VCF files: validate samplesheet, remove annotations, combine VCFs, filter SVs, and apply quality filters
//

include { REMOVE_ANNOTATIONS } from '../../../subworkflows/local/remove_annotations'
include { COMBINE_VCF } from '../../../subworkflows/local/combine_vcf'
include { SV_MASK_BED } from '../../../subworkflows/local/sv_mask_bed/main'
include { FILTER_LOWCONF } from '../../../subworkflows/local/filter_lowconf/main'

include { paramsSummaryMap                 } from 'plugin/nf-schema'
include { samplesheetToList                } from 'plugin/nf-schema'

workflow PREPROCESS_VCF {
    
    take:
    samplesheet_path    // path: samplesheet CSV file
    
    main:
     ch_versions = Channel.empty()
    
    // Validate samplesheet 
    samplesheetToList(samplesheet_path, "${projectDir}/assets/schema_input.json")
    
    // Parse validated samplesheet into a Nextflow channel
    samples_ch = Channel
        .fromPath(samplesheet_path, checkIfExists: true)
        .splitCsv(header: true)
        .map { row ->
            def meta = [
                id  : row.fam_id,
                proband_id: row.proband_id,
                mother_id: row.mother_id,
                father_id: row.father_id,
                sv_p: row.path_sv_proband ?: '-',
                sv_m: row.path_sv_mother  ?: '-',
                sv_f: row.path_sv_father  ?: '-'
            ]
            def vcfs = [
                file(row.path_vcf_proband, checkIfExists: true),
                file(row.path_vcf_mother, checkIfExists: true),
                file(row.path_vcf_father, checkIfExists: true)
            ]
            tuple(meta, vcfs)
        }

    // Step 1: Filter autosomes and remove annotations (Keep only essential fields)
    REMOVE_ANNOTATIONS(samples_ch)
    ch_versions = ch_versions.mix(REMOVE_ANNOTATIONS.out.versions)
    
    // Step 2: Combine trio VCFs (intersection or union) into a single merged file
    COMBINE_VCF(REMOVE_ANNOTATIONS.out.vcfs)
    ch_versions = ch_versions.mix(COMBINE_VCF.out.versions)

    // Step 3: Filter Structural Variants
    SV_MASK_BED(COMBINE_VCF.out.vcfs)
    ch_versions = ch_versions.mix(SV_MASK_BED.out.versions)
    
    // Step 4: Apply low confidence filters
    FILTER_LOWCONF(SV_MASK_BED.out.vcfs)
    ch_versions = ch_versions.mix(FILTER_LOWCONF.out.versions)
    
    emit:
    vcfs     = FILTER_LOWCONF.out.vcfs    // channel: [meta, vcf, tbi] - Final processed VCFs
    versions = ch_versions                // channel: versions.yml
}