//
// Event detection workflow
//
// Implements the core UPDhmm R-package logic for trio-based UPD detection.
// Steps include:
//   - Trio VCF preprocessing with quality-aware genotype encoding
//   - HMM-based UPD event detection across chromosomes
//   - Event collapsing to summarize UPD regions per sample and chromosome
//

include { UPDHMM_VCFCHECK        } from '../../../modules/local/updhmm/vcfcheck/main'
include { UPDHMM_CALCULATEEVENTS } from '../../../modules/local/updhmm/calculateevents/main' 
include { UPDHMM_COLLAPSEEVENTS  } from '../../../modules/local/updhmm/collapseevents/main'

workflow EVENT_DETECTION {
    
    take:
    ch_vcfs    // channel: [val(meta), path(vcf), path(tbi)]
    
    main:
    
    //
    // Validate VCF structure and format
    //
    UPDHMM_VCFCHECK(ch_vcfs)
    
    //
    // Calculate UPD events from processed VCF
    //
    UPDHMM_CALCULATEEVENTS(UPDHMM_VCFCHECK.out.processed_vcf)
    
    //
    // Collapse UPD events
    //
    UPDHMM_COLLAPSEEVENTS(UPDHMM_CALCULATEEVENTS.out.upd_events_rds)
    
    emit:
    upd_events_txt    = UPDHMM_CALCULATEEVENTS.out.upd_events_txt   // channel: [val(meta), path(txt)]
    upd_collapsed_txt = UPDHMM_COLLAPSEEVENTS.out.upd_collapsed_txt // channel: [val(meta), path(txt)]
}