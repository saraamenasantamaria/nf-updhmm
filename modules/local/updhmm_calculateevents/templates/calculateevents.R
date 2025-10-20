#!/usr/bin/env Rscript

################################################
################################################
## LOAD LIBRARIES                            ##
################################################
################################################

suppressPackageStartupMessages({
    library(UPDhmm)
    library(BiocParallel)
    library(parallel)
})

################################################
## PARSE NEXTFLOW VARIABLES                  ##
################################################

# Input files
input_rds <- "${processed_vcf_rds}"

# Output configuration
prefix <- "${prefix}"

# Runtime options
verbose <- as.logical("${verbose}")
add_ratios <- as.logical("${add_ratios}")
cpus <- as.integer("${cpus}")

################################################
## VALIDATE INPUT FILES                      ##
################################################

if (!file.exists(input_rds)) {
    cat("[ERROR] Input RDS file does not exist:", input_rds, "\\n")
    quit(status = 1)
}

################################################
## LOAD PROCESSED VCF                        ##
################################################

processedVcf <- readRDS(input_rds)


################################################
## SETUP PARALLEL PROCESSING                 ##
################################################

# Configure BiocParallel backend
if (cpus > 1) {
    bp_param <- MulticoreParam(workers = cpus)
} else {
    bp_param <- SerialParam()
}


################################################
## CALCULATE UPD EVENTS                      ##
################################################

updEvents <- tryCatch({
    calculateEvents(
        processedVcf, 
        verbose = verbose, 
        BPPARAM = bp_param, 
        add_ratios = add_ratios
    )
}, error = function(e) {
    cat("[ERROR] calculateEvents failed\\n")
    cat("[ERROR] ", conditionMessage(e), "\\n")
    quit(status = 1)
})


################################################
## SAVE OUTPUTS                              ##
################################################

# Save as text file
results_file <- paste0(prefix, ".upd_events.txt")

write.table(
    updEvents, 
    file = results_file, 
    sep = "\\t", 
    row.names = FALSE, 
    quote = FALSE
)


# Save as RDS file
rds_file <- paste0(prefix, ".upd_events.rds")

saveRDS(updEvents, file = rds_file)


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
biocparallel.version <- as.character(packageVersion('BiocParallel'))

writeLines(
    c(
        '"${task.process}":',
        paste0('    r-base: "', r.version, '"'),
        paste0('    bioconductor-updhmm: "', updhmm.version, '"'),
        paste0('    bioconductor-biocparallel: "', biocparallel.version, '"')
    ),
    'versions.yml'
)
