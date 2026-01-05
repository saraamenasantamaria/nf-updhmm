/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { REMOVE_ANNOTATIONS           } from '../subworkflows/local/remove_annotations'
include { VCF_COMBINE                  } from '../subworkflows/local/vcf_combine'
include { GVCF_COMBINE                 } from '../subworkflows/local/gvcf_combine'
include { SV_MASK_BED                  } from '../subworkflows/local/sv_mask_bed'
include { FILTER_LOWCONF               } from '../subworkflows/local/filter_lowconf'
include { EVENT_DETECTION              } from '../subworkflows/local/event_detection/main'

include { paramsSummaryMap             } from 'plugin/nf-schema'
include { softwareVersionsToYAML       } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText       } from '../subworkflows/local/utils_nfcore_updhmm_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow UPDHMM {

    take:
    ch_samplesheet  // channel: samplesheet read in from --input

    main:
    ch_versions = Channel.empty()
    
    //
    // Parse samplesheet into channel with trio metadata
    //
    ch_samples = ch_samplesheet
        .splitCsv(header: true)
        .map { row ->
            def meta = [
                id         : row.fam_id,
                proband_id : row.proband_id,
                mother_id  : row.mother_id,
                father_id  : row.father_id,
                sv_p       : row.path_sv_proband ?: '-',
                sv_m       : row.path_sv_mother  ?: '-',
                sv_f       : row.path_sv_father  ?: '-'
            ]
            def vcfs = [
                file(row.path_vcf_proband, checkIfExists: true),
                file(row.path_vcf_mother, checkIfExists: true),
                file(row.path_vcf_father, checkIfExists: true)
            ]
            [meta, vcfs]
        }
    
    
    //
    // SUBWORKFLOW: Filter autosomes and remove non-essential VCF annotations
    //
    REMOVE_ANNOTATIONS(
        ch_samples,
        params.is_gvcf,
        params.apply_vaf_filter
    )
    ch_versions = ch_versions.mix(REMOVE_ANNOTATIONS.out.versions)

    //
    // SUBWORKFLOW: Combine trio VCFs (strategy depends on input format)
    //
    if (params.is_gvcf) {
        //
        // GVCF mode: Joint calling with GATK CombineGVCFs + GenotypeGVCFs
        //
        GVCF_COMBINE(
            REMOVE_ANNOTATIONS.out.vcf,
            params.fasta,
            params.fai,
            params.dict
        )
        ch_versions = ch_versions.mix(GVCF_COMBINE.out.versions)
        ch_combined_vcfs = GVCF_COMBINE.out.vcf
    } else {
        //
        // VCF mode: Intersection and merge with bcftools
        //
        VCF_COMBINE(
            REMOVE_ANNOTATIONS.out.vcf,
            params.perform_intersection
        )
        ch_versions = ch_versions.mix(VCF_COMBINE.out.versions)
        ch_combined_vcfs = VCF_COMBINE.out.vcf
    }

    //
    // SUBWORKFLOW: Mask structural variant regions
    //
    SV_MASK_BED(ch_combined_vcfs)
    ch_versions = ch_versions.mix(SV_MASK_BED.out.versions)

    //
    // SUBWORKFLOW: Apply quality filters for high-confidence variants
    //
    FILTER_LOWCONF(
        SV_MASK_BED.out.vcf,
        params.perform_intersection,
        params.apply_vaf_correction
    )
    ch_versions = ch_versions.mix(FILTER_LOWCONF.out.versions)

    //
    // SUBWORKFLOW: UPD event detection and HMM segmentation
    //
    EVENT_DETECTION(FILTER_LOWCONF.out.vcf)
    //ch_versions = ch_versions.mix(EVENT_DETECTION.out.versions)
    
// El proceso BCFTOOLS_QUERY no genera correctamente versions.yml por eso esto da error
//    //
//    // Collate and save software versions
//    //
//    softwareVersionsToYAML(ch_versions)
//        .collectFile(
//            storeDir: "${params.outdir}/pipeline_info",
//            name: 'nf_core_pipeline_software_mqc_versions.yml',
//            sort: true,
//            newLine: true
//        ).set { ch_collated_versions }

    emit:
    versions       = ch_versions

}