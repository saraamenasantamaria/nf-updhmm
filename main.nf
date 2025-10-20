#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include { PREPROCESS_VCF } from './subworkflows/local/preprocess_vcf/main'
include { VCF_CHECK } from './modules/local/vcf_check/main'
include { CALCULATE_EVENTS } from './modules/local/calculate_events/main' 
include { COLLAPSE_EVENTS } from './modules/local/collapse_events/main'


workflow {
    
    // Step 1: Preprocess VCFs (validation, annotation removal, merging, filtering)
    PREPROCESS_VCF(params.input)

    // Step 2: VCF Check (validate and prepare for UPD analysis)
    VCF_CHECK(PREPROCESS_VCF.out.vcfs)
    
    // Step 3: Calculate Events (compute UPD events)
    CALCULATE_EVENTS(VCF_CHECK.out.processed_vcf)
    CALCULATE_EVENTS.out.upd_events_txt.view { "UPD events (TXT): $it" }
    
    // Step 4: Collapse Events (merge adjacent/overlapping events)
    COLLAPSE_EVENTS(CALCULATE_EVENTS.out.upd_events_rds)
    COLLAPSE_EVENTS.out.upd_collapsed_txt.view { "Collapsed events (TXT): $it" }

}

