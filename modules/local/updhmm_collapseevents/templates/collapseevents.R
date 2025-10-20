#!/usr/bin/env Rscript

################################################
################################################
## LOAD LIBRARIES                            ##
################################################
################################################

suppressPackageStartupMessages({
    library(UPDhmm)
})

################################################
## PARSE NEXTFLOW VARIABLES                  ##
################################################

# Input files
input_rds <- "${upd_events_rds}"

# Output configuration
prefix <- "${prefix}"

# Runtime options
verbose <- as.logical("${verbose}")

################################################
## VALIDATE INPUT FILES                      ##
################################################

if (!file.exists(input_rds)) {
    cat("[ERROR] Input RDS file does not exist:", input_rds, "\\n")
    quit(status = 1)
}

################################################
## LOAD UPD EVENTS                           ##
################################################

updEvents <- readRDS(input_rds)


################################################
## COLLAPSE UPD EVENTS                       ##
################################################

collapsed <- tryCatch({
    collapseEvents(updEvents)
}, error = function(e) {
    cat("[ERROR] collapseEvents failed\\n")
    cat("[ERROR] ", conditionMessage(e), "\\n")
    quit(status = 1)
})

################################################
## SAVE OUTPUTS                              ##
################################################

# Save as text file
collapsed_file <- paste0(prefix, ".upd_collapsed.txt")

write.table(
      collapsed, 
      file = collapsed_file, 
      sep = "\\t", 
      row.names = FALSE, 
      quote = FALSE
  )


# Save as RDS file
collapsed_rds_file <- paste0(prefix, ".upd_collapsed.rds")

saveRDS(collapsed, file = collapsed_rds_file)


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

writeLines(
    c(
        '"${task.process}":',
        paste0('    r-base: "', r.version, '"'),
        paste0('    bioconductor-updhmm: "', updhmm.version, '"')
    ),
    'versions.yml'
)

