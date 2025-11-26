//
// Event detection workflow: VCF validation, UPD event calculation, and event collapsing
//

include { VCF_CHECK                     } from '../../../modules/local/vcf_check/main'
include { CALCULATE_EVENTS              } from '../../../modules/local/calculate_events/main' 
include { COLLAPSE_EVENTS               } from '../../../modules/local/collapse_events/main'

workflow EVENT_DETECTION {
    
    take:
    vcfs_ch    // channel: [meta, vcf, tbi]
    
    main:
    //ch_versions = Channel.empty()
    
    VCF_CHECK (vcfs_ch)
    //ch_versions = ch_versions.mix(VCF_CHECK.out.versions.first())
    
    
    CALCULATE_EVENTS (VCF_CHECK.out.processed_vcf)
    //ch_versions = ch_versions.mix(CALCULATE_EVENTS.out.versions.first())
    
    COLLAPSE_EVENTS (CALCULATE_EVENTS.out.upd_events_rds)
    //ch_versions = ch_versions.mix(COLLAPSE_EVENTS.out.versions.first())
    
    emit:
    upd_events_txt     = CALCULATE_EVENTS.out.upd_events_txt     // channel: [ meta, txt ]
    upd_collapsed_txt  = COLLAPSE_EVENTS.out.upd_collapsed_txt   // channel: [ meta, txt ]    
    //versions           = ch_versions                             // channel: versions.yml
}