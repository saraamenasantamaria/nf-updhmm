/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PREPROCESSING      } from '../subworkflows/local/preprocessing/main'
include { EVENT_DETECTION    } from '../subworkflows/local/event_detection/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow UPDHMM {

    take:
    ch_samplesheet  


    main:
    ch_fasta = params.fasta ? Channel.fromPath(params.fasta).collect() : Channel.empty()
    ch_fai   = params.fai   ? Channel.fromPath(params.fai).collect()   : Channel.empty()
    ch_dict  = params.dict  ? Channel.fromPath(params.dict).collect()  : Channel.empty()

    //
    // SUBWORKFLOW: Preprocess VCFs/GVCFs (validation, annotation removal, merging, filtering)
    //
    PREPROCESSING(
        ch_samplesheet,
        params.is_gvcf ?: false,
        params.perform_intersection ?: false,
        ch_fasta,
        ch_fai,
        ch_dict,
        params.apply_vaf_filter ?: false,
        params.apply_vaf_correction ?: false
    )

    //
    // SUBWORKFLOW: Event Detection (VCF check, calculate events, collapse events)
    //
    EVENT_DETECTION(PREPROCESSING.out.vcf)

}