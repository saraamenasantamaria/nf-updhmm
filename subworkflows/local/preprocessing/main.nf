//
// VCF preprocessing workflow
//
// Comprehensive trio VCF preparation for downstream UPD detection analysis.
// This workflow handles both VCF and GVCF inputs, performing:
//   - Samplesheet validation with trio structure enforcement
//   - Autosome filtering and VCF annotation cleanup
//   - Trio-aware VCF/GVCF merging with appropriate tools
//   - Structural variant region masking
//   - Quality-based filtering for high-confidence variant calls
//

include { REMOVE_ANNOTATIONS } from '../../../subworkflows/local/remove_annotations'
include { VCF_COMBINE        } from '../../../subworkflows/local/vcf_combine'
include { GVCF_COMBINE       } from '../../../subworkflows/local/gvcf_combine'
include { SV_MASK_BED        } from '../../../subworkflows/local/sv_mask_bed/main'
include { FILTER_LOWCONF     } from '../../../subworkflows/local/filter_lowconf/main'

include { paramsSummaryMap   } from 'plugin/nf-schema'
include { samplesheetToList  } from 'plugin/nf-schema'

workflow PREPROCESSING {
    
    take:
    val_samplesheet          // file: path to samplesheet CSV file
    val_is_gvcf              // boolean: whether input files are GVCFs
    val_perform_intersection // boolean: whether to perform intersection
    val_fasta                // file: path to reference fasta
    val_fai                  // file: path to fasta index
    val_dict                 // file: path to reference dict
    val_apply_vaf_filter     // boolean: whether to apply VAF ambiguous region masking
    val_apply_vaf_correction // boolean: whether to apply VAF genotype correction
    
    main:
    ch_versions = Channel.empty()
    
    //
    // Validate samplesheet structure and trio completeness
    //
    samplesheetToList(val_samplesheet, "${projectDir}/assets/schema_input.json")
    
    //
    // Parse samplesheet into channel with trio metadata
    //
    ch_samples = Channel
        .fromPath(val_samplesheet, checkIfExists: true)
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
    // Filter autosomes and strip non-essential VCF annotations
    //
    REMOVE_ANNOTATIONS(ch_samples, val_is_gvcf, val_apply_vaf_filter)
    ch_versions = ch_versions.mix(REMOVE_ANNOTATIONS.out.versions)
    
    //
    // Combine trio VCFs into single merged file
    // Strategy depends on input format (VCF vs GVCF)
    //
    if (val_is_gvcf) {
        //
        // GVCF path: Use GATK CombineGVCFs + GenotypeGVCFs for joint calling
        //
        GVCF_COMBINE(
            REMOVE_ANNOTATIONS.out.vcf,
            val_fasta,
            val_fai,
            val_dict
        )
        ch_versions = ch_versions.mix(GVCF_COMBINE.out.versions)
        ch_combined_vcfs = GVCF_COMBINE.out.vcf
    } else {
        //
        // VCF path: Use bcftools intersection and merge workflow
        //
        VCF_COMBINE(
            REMOVE_ANNOTATIONS.out.vcf,
            val_perform_intersection
        )
        ch_versions = ch_versions.mix(VCF_COMBINE.out.versions)
        ch_combined_vcfs = VCF_COMBINE.out.vcf
    }

    //
    // Mask problematic structural variant regions
    //
    SV_MASK_BED(ch_combined_vcfs)
    ch_versions = ch_versions.mix(SV_MASK_BED.out.versions)
    
    //
    // Apply quality filters for high-confidence variant selection
    //
    FILTER_LOWCONF(
        SV_MASK_BED.out.vcf,
        val_perform_intersection,
        val_apply_vaf_correction
    )
    ch_versions = ch_versions.mix(FILTER_LOWCONF.out.versions)
    
    emit:
    vcf      = FILTER_LOWCONF.out.vcf    // channel: [val(meta), path(vcf), path(tbi)]
    versions = ch_versions                 // channel: [path(versions.yml)]
}