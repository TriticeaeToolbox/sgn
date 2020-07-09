# DEPENDENCIES:
# lsmeans


#
# Summarize Trials and Traits
#
# Calculate LSMeans across all trials for specified traits
# and summarize trial means for individual traits.
#
# This will generate CSV tables and metadata files 
# in the specified output directory
#   - lsmeans.csv
#   - lsmeans.metadata.csv
#   - trait_1.csv
#   - trait_1.metadata.csv
#     ... for each trait
#
# Params:
#   src = filepath to source data in csv format:
#     trait = breedbase trait name
#     trial = trial code / name
#     accession = accession name
#     value = trait value
#   out = output directory for writing tables and metadata
#
summarizeTrialsAndTraits <- function(src, out) {

  # Read the data
  data <- read.csv(src, stringsAsFactors = FALSE)

  # Compute the LSMeans
  tableReportParams <- computeLSMeans(data)

  # Generate the ls means table
  lsmeans <- generateLSMeansTable(data, tableReportParams)

  # Generate the trait summaries
  traits <- generateTraitSummaries(data, tableReportParams)

  # Write tables to output directory  
  write.csv(lsmeans$table, paste0(out, "/lsmeans.csv"), row.names = FALSE)
  write.csv(lsmeans$metadata, paste0(out, "/lsmeans.metadata.csv"), row.names = FALSE)
  for ( trait_name in names(traits) ) {
    write.csv(traits[[trait_name]]$table, paste0(out, "/", trait_name, ".csv"), row.names = FALSE)
    write.csv(traits[[trait_name]]$metadata, paste0(out, "/", trait_name, ".metadata.csv"), row.names = FALSE)
  }
  
}


#
# Generate the LS Means Summary Table and Metadata
#
# Calculate LSMeans across all trials and summarize for 
# each trait and accession
#
# Params:
#   data = source data
#   tableReportParams = LSMeans results
#
# Returns: list
#   table = ls means summary table
#   metadata = ls means metadata (trait name, trait id, LSD, HSD)
#
generateLSMeansTable <- function(data, tableReportParams) {

  # Get traits and accessions from data
  traits <- unique(data$trait)
  sorted_accessions <- sort(unique(data$accession))

  # Setup the LS Means and metadata tables
  lsmeans <- data.frame(accession=sorted_accessions)
  lsmeans_metadata <- data.frame(trait_code=character(), trait_name=character(), lsd=numeric(), hsd=numeric())
  
  # Parse each trait result
  lsmeans_traits <- c()
  for ( i in c(1:ncol(tableReportParams)) ) {
    accessions <- tableReportParams[,i]$fitLM$xlevels$lineName
    means <- tableReportParams[,i]$lsmeans
    lsd <- tableReportParams[,i]$leastSigDiff
    hsd <- tableReportParams[,i]$tukeysHSD
    
    # Get the means for each accession
    lsmeans_trait <- c()
    for ( accession in sorted_accessions ) {
      if ( accession %in% accessions ) {
        for ( j in c(1:length(accessions)) ) {
          if ( accessions[j] == accession ) {
            lsmeans_trait <- c(lsmeans_trait, means[j])
          }
        }
      }
      else {
        lsmeans_trait <- c(lsmeans_trait, NA)
      }
    }

    # Add the trait means to the table
    trait_code <- paste0("trait_", i)
    trait_name <- traits[i]
    lsmeans[[trait_name]] <- lsmeans_trait

    # Build the metadata table
    md_row <- data.frame(trait_code = trait_code, trait_name = trait_name, lsd = lsd, hsd = hsd)
    lsmeans_metadata <- rbind(lsmeans_metadata, md_row)
  }

  # Return the table and metadata
  return(list(
    table = lsmeans,
    metadata = lsmeans_metadata
  ))

}


#
# Generate Trait Summary Tables and Metadata
#
# Calculate trial means and generate summary tables for each 
# trait containing accession and trial means across trials
#
# Params:
#   data = source data
#   tableReportParams = LSMeans results
#
# Returns: a vector of lists:
#   table = trait summary table
#   metadata = trait metadata
#
generateTraitSummaries <- function(data, tableReportParams) {

  # Get traits and accessions from data
  traits <- unique(data$trait)
  sorted_accessions <- sort(unique(data$accession))

  # List of trait summary info
  trait_summary_info <- list()

  # Parse each trait
  for ( i in c(1:ncol(tableReportParams)) ) {
    trait_code <- paste0("trait_", i)
    trait_name <- traits[i]
    trials <- tableReportParams[,i]$trialNames
    trialMeans <- tableReportParams[,i]$trialMeans
    traitData <- tableReportParams[,i]$fitLM$model
    lsd <- tableReportParams[,i]$leastSigDiff
    hsd <- tableReportParams[,i]$tukeysHSD

    # Setup trait summary and metadata tables
    trait_summary <- data.frame(accession=c(sorted_accessions, "Trial Mean"))
    trait_summary_metadata <- data.frame(trait_code = trait_code, trait_name = trait_name, lsd = lsd, hsd = hsd)

    # Parse each trial
    for ( j in c(1:length(trials)) ) {
      trial <- trials[j]
      trialMean <- trialMeans[j]
      accessionMeans <- c()

      # Parse each accession
      for ( accession in sorted_accessions ) {
        accessionData <- traitData[which(traitData$trial == trial & traitData$lineName == accession),]$value
        accessionMean <- mean(accessionData)
        accessionMeans <- c(accessionMeans, accessionMean)
      }
      accessionMeans <- c(accessionMeans, trialMean)

      # Add Trial Means to summary table
      trait_summary[[trial]] <- accessionMeans
    }

    # Add to list of trait summary info
    trait_summary_info[[trait_code]] <- list(
      table = trait_summary,
      metadata = trait_summary_metadata
    )
  }

  # Return the trait summary info
  return(trait_summary_info)

}




#
# THE FOLLOWING CODE WAS TAKEN FROM T3/Classic
# Authors: Dave Matthews, Clay Birkett
# Source: https://github.com/TriticeaeToolbox/T3/blob/master/R/TableReportParameters.R
#

computeLSMeans <- function(oneCol) {
  library(lsmeans)

  colnames(oneCol) <- c("trait", "trial", "lineName", "value")

  traitsVec <- unique(oneCol$trait)
  trialVec <- unique(oneCol$trial)

  if (length(trialVec) > 1) {
    tableReportParms <- sapply(traitsVec, function(trait) {
      analyzeTrait(trait, oneCol)
    })
  } 
  else {
    tableReportParms <- sapply(traitsVec, function(trait) {
      summaryTrait(trait, oneCol)
    })
  }

  return(tableReportParms)
}


fitLMbyTrait <- function(trait, data){
  data <- data[data$trait == trait,]
  lines <- data$lineName
  fitLM <- lm(value ~ trial + lineName, data=data)
  return(fitLM)
}

calcLSmeanParms <- function(fitLM){
  lineLSmeans <- summary(lsmeans(fitLM, "lineName"))
  meanSE <- mean(lineLSmeans$SE)
  meanDF <- mean(lineLSmeans$df)
  leastSigDiff <- sqrt(2)*meanSE*qt(1 - 0.025, meanDF)
  tukeysHSD <- meanSE*qtukey(1 - 0.05, nrow(lineLSmeans), meanDF) # Tukey is already two-sided
  trialLSmeans <- summary(lsmeans(fitLM, "trial"))
  return(list(lsmeans=lineLSmeans$lsmean, leastSigDiff=leastSigDiff, tukeysHSD=tukeysHSD, trialNames=levels(trialLSmeans$trial), trialMeans=trialLSmeans$lsmean, fitLM=fitLM))
}

analyzeTrait <- function(trait, oneCol){
  fitLM <- fitLMbyTrait(trait, oneCol)
  return(calcLSmeanParms(fitLM))
}

summaryTrait <- function(trait, oneCol){
  data <- oneCol[oneCol$trait == trait,]
  trialMeans <- mean(data$value, na.rm=TRUE)
  return(list(trialNames=levels(data$trial), trialMeans=trialMeans))
}





# Parse R CMD BATCH args
args=(commandArgs(TRUE))
if ( length(args) != 2 ) {
  print("ERROR: Incorrect arguments provided")
} else {
  for(i in 1:length(args)) {
    eval(parse(text=args[[i]]))
  }
  summarizeTrialsAndTraits(src, out)
}