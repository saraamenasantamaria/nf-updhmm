/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFSCHEMA_PLUGIN       } from '../../nf-core/utils_nfschema_plugin'
include { UTILS_NEXTFLOW_PIPELINE     } from '../../nf-core/utils_nextflow_pipeline'
include { paramsSummaryMap            } from 'plugin/nf-schema'
include { samplesheetToList           } from 'plugin/nf-schema'
include { completionEmail             } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary           } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification              } from '../../nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW TO INITIALISE PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    validate_params   // boolean: Validate parameters via schema
    monochrome_logs   // boolean: Disable colored logs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE(
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    UTILS_NFSCHEMA_PLUGIN(
        workflow,
        validate_params,
        null,
        params.help,
        params.help_full,
        params.show_hidden,
        params.before_text,
        params.after_text,
        params.help_command
    )
    
    //
    // Custom parameter validation
    //
    validateInputParameters()
    
    //
    // Create input channel from samplesheet
    //
    ch_samplesheet = Channel.fromPath(input, checkIfExists: true)
    
    //
    // Validate samplesheet format
    //
    if (validate_params) {
        samplesheetToList(input, "${projectDir}/assets/schema_input.json")
    }

    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    SUBWORKFLOW FOR PIPELINE COMPLETION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow PIPELINE_COMPLETION {

    take:
    email           //  string: email address
    email_on_fail   //  string: email address sent on pipeline failure
    plaintext_email // boolean: Send plain-text email instead of HTML
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output
    hook_url        //  string: hook URL for notifications
    multiqc_report  //  string: Path to MultiQC report

    main:
    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")

    //
    // Completion email and summary
    //
    workflow.onComplete {
        if (email || email_on_fail) {
            completionEmail(
                summary_params,
                email,
                email_on_fail,
                plaintext_email,
                outdir,
                monochrome_logs,
                multiqc_report
            )
        }
        
        if (hook_url) {
            imNotification(summary_params, hook_url)
        }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Validate input parameters
//
def validateInputParameters() {

    def errors = []
    
    // Validación: input es requerido
    if (!params.input) {
        errors << "Input samplesheet must be provided with --input"
    }
    
    // Validación condicional: GVCF requiere archivos de referencia
    if (params.is_gvcf) {
        if (!params.fasta) {
            errors << "When --is_gvcf is true, you must provide --fasta"
        }
        if (!params.fai) {
            errors << "When --is_gvcf is true, you must provide --fai"
        }
        if (!params.dict) {
            errors << "When --is_gvcf is true, you must provide --dict"
        }
    }
    
    if (errors.size() > 0) {
        error("Parameter validation failed:\n" + errors.join("\n"))
    }
    
}

//
// Generate methods description for MultiQC
//
def methodsDescriptionText(mqc_methods_yaml) {
    // Placeholder for methods description
    def methods_text = """
    ## Methods
    
    Data was processed using the nf-core/updhmm pipeline.
    """.stripIndent()
    
    return methods_text
}