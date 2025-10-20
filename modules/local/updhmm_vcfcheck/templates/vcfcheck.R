#!/usr/bin/env Rscript

################################################
################################################
## LOAD LIBRARIES                            ##
################################################
################################################

suppressPackageStartupMessages({
    library(UPDhmm)
    library(VariantAnnotation)
})

################################################
## PARSE NEXTFLOW VARIABLES                  ##
################################################

# Input files
vcf_file <- "${vcf}"
tbi_file <- "${tbi}"

# Output configuration
prefix <- "${prefix}"
genome_build <- "${genome_build}"

# Runtime options
verbose <- as.logical("${verbose}")
args <- "${args}"


################################################
## VALIDATE INPUT FILES                      ##
################################################

if (!file.exists(vcf_file)) {
    cat("[ERROR] VCF file does not exist:", vcf_file, "\\n")
    quit(status = 1)
}

################################################
## READ VCF FILE                             ##
################################################

vcf <- readVcf(vcf_file, genome_build)


################################################
## EXTRACT SAMPLE INFORMATION                ##
################################################

sample_names <- colnames(geno(vcf)\$GT)


################################################
## RUN VCF CHECK                             ##
################################################

tryCatch({
    processedVcf <- vcfCheck(vcf, 
                           proband = sample_names[1], 
                           mother = sample_names[2], 
                           father = sample_names[3])
}, error = function(e) {
    cat("ERROR in vcfCheck:", conditionMessage(e), "\\n")
    quit(status = 1)
})


################################################
## SAVE OUTPUTS                              ##
################################################

processed_rds_file <- paste0(prefix, ".processed.rds")

saveRDS(processedVcf, file = processed_rds_file)
  

################################################
## SAVE SESSION INFO                         ##
################################################

session_info_file <- paste0(prefix, ".R_sessionInfo.log")

sink(session_info_file)
sessionInfo()
sink()

################################################
## WRITE VERSIONS FILE                       ##
################################################

r.version <- strsplit(version[['version.string']], ' ')[[1]][3]
updhmm.version <- as.character(packageVersion('UPDhmm'))
variantannotation.version <- as.character(packageVersion('VariantAnnotation'))

writeLines(
    c(
        '"${task.process}":',
        paste0('    r-base: "', r.version, '"'),
        paste0('    bioconductor-updhmm: "', updhmm.version, '"'),
        paste0('    bioconductor-variantannotation: "', variantannotation.version, '"')
    ),
    'versions.yml'
)