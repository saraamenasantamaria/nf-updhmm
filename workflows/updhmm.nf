/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PREPROCESS_VCF                } from '../subworkflows/local/preprocess_vcf/main'
include { EVENT_DETECTION               } from '../subworkflows/local/event_detection/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow UPDHMM {

    take:
    samplesheet_path

    main:

    //
    // SUBWORKFLOW: Preprocess VCFs (validation, annotation removal, merging, filtering)
    //
    PREPROCESS_VCF(samplesheet_path)

    //
    // SUBWORKFLOW: Event Detection (VCF check, calculate events, collapse events)
    //
    EVENT_DETECTION(PREPROCESS_VCF.out.vcfs)

}