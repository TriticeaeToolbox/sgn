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
#
#     NOTE:
#     1. Data can have a mix of trials where some have only one value per
#     accession per trait (i.e., entry mean data) and others have multiple
#     values per accession per trait (i.e., plot level data). If a trial has
#     plot level data, the analysis will calculate and report the trial-specific
#     LSD and HSD.
#     2. The analysis works even if for a specific trait, it is present in only
#     one trial, so that there is no multi-trial analysis to give a multi-trial
#     LSD and HSD.
#
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
  write.csv(lsmeans$metadata, paste0(out, "/lsmeans.metadata.csv"),
            row.names = FALSE)
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
  traits <- colnames(tableReportParams)
  sorted_accessions <- data$accession |> unique() |> sort()

  # Setup the LS Means and metadata tables
  lsmeans <- data.frame(accession=sorted_accessions)
  lsmeans_metadata <- data.frame(trait_code=character(), trait_name=character(), lsd=numeric(), hsd=numeric())

  # Parse each trait result
  for ( i in c(1:ncol(tableReportParams)) ) {
    accessions <- tableReportParams[,i]$fitLM$xlevels$lineName
    means <- tableReportParams[,i]$lsmeans
    lsd <- tableReportParams[,i]$leastSigDiff
    hsd <- tableReportParams[,i]$tukeysHSD

    # Set Trait Code and get Trait Name
    trait_code <- paste0("trait_", i)
    trait_name <- traits[i]

    # Collect accession means
    lsmeans_trait <- rep(NA, length(sorted_accessions))
    names(lsmeans_trait) <- sorted_accessions
    lsmeans_trait[accessions] <- means

    # Add the trait means to the table
    lsmeans[[trait_code]] <- lsmeans_trait

    # Build the metadata table
    md_row <- data.frame(trait_code = trait_code, trait_name = trait_name, lsd = lsd, hsd = hsd)
    lsmeans_metadata <- rbind(lsmeans_metadata, md_row)
  }#END for each column in tableReportParams

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
  traits <- colnames(tableReportParams)
  sorted_accessions <- data$accession |> unique() |> sort()

  # List of trait summary info
  trait_summary_info <- list()

  # Parse each trait
  for ( i in c(1:ncol(tableReportParams)) ) {
    trait_code <- paste0("trait_", i)
    trait_name <- traits[i]
    trials <- tableReportParams[,i]$trialNames
    trialMeans <- tableReportParams[,i]$trialMeans
    trialLSDs <- tableReportParams[,i]$trialLSD
    trialHSDs <- tableReportParams[,i]$trialHSD
    # Whether the means came from an lm analysis or a tapply, they are sorted
    # in order of the lineName
    oneValPerAccPerTrial <- tableReportParams[,i]$fitLM$model
    lsd <- tableReportParams[,i]$leastSigDiff
    hsd <- tableReportParams[,i]$tukeysHSD

    # Setup trait summary and metadata tables
    trait_summary <- data.frame(accession=c(sorted_accessions,
                                            "Trial Mean",
                                            "Trial LSD",
                                            "Trial HSD"))
    trait_summary_metadata <- data.frame(trait_code = trait_code, trait_name = trait_name, lsd = lsd, hsd = hsd)

    # Parse each trial
    for ( j in c(1:length(trials)) ) {
      trial <- trials[j]
      trialMean <- trialMeans[j]
      trialLSD <- trialLSDs[j]
      trialHSD <- trialHSDs[j]

      # Collect accession means
      valsInTrial <- oneValPerAccPerTrial[oneValPerAccPerTrial$trial == trial,]
      lsmeans_trial <- rep(NA, length(sorted_accessions))
      names(lsmeans_trial) <- sorted_accessions
      lsmeans_trial[valsInTrial$lineName] <- valsInTrial$value
      lsmeans_trial <- c(lsmeans_trial, trialMean, trialLSD, trialHSD)

      # Add Trial Means to summary table
      trait_summary[[trial]] <- lsmeans_trial
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

# The following code was written in July 2025 by Jean-Luc Jannink
# It aims to make the summary reports more robust and flexible so that more
# different kinds of trials can be shoved in there
#
# Params:
#   oneCol = data.frame where all the phenotypes are in one column.  There are
#   four columns: trait, trial, lineName, value
#   For any trait and trial there are three possibilities:
#   1. There is no data
#   2. There is one phenotype per lineName. This would be if T3 only stores the
#   entry mean for each line in the trial
#   3. There are >1 phenotype per lineName. This would be if T3 stores the plot-
#   level data for each line in the trial
#
# Returns:
#   tableReportParms = LSMeans results
#
# Pseudocode:
# 1  For each trait
# 2    Construct a data.frame that has one value per line per trial:
# 3    For each trial
# 4      If the trial has plot level data, calculate LSmeans and retain the SE
# 5      If the trial has entry mean data, return those with SE set to missing
# 6    If there was only one trial, return the LSmeans for the trial
# 7    If there were >1 trial, calculate overall LSmeans, weighted by the SE
#
computeLSMeans <- function(oneCol) {
  library(lsmeans)

  colnames(oneCol) <- c("trait", "trial", "lineName", "value")
  oneCol <- oneCol[!is.na(oneCol$value),] # remove rows with missing data

  traitVec <- unique(oneCol$trait)
  trialVec <- unique(oneCol$trial)

  # 2    Construct a data.frame that has one value per line per trait*trial
  valueRes <- stdErrRes <- NULL
  for (trait in traitVec){
    for (trial in trialVec){
      # Figure out if there is data for this trait x trial combo
      nObs <- sum(oneCol$trait == trait & oneCol$trial == trial)
      if (nObs > 1){
        res <- processOneTrial(trait, trial, oneCol)
        meanSE <- mean(res$SE)
        meanDF <- mean(res$df)
        if (is.nan(meanSE)) meanSE <- NA
        if (!is.na(meanSE)){
          leastSigDiff <- sqrt(2)*meanSE*qt(1 - 0.025, meanDF)
          tukeysHSD <- meanSE*qtukey(1 - 0.05, nrow(res), meanDF)
        } else leastSigDiff <- tukeysHSD <- NA
        stdErrRes <- rbind(stdErrRes, c(trait=trait, trial=trial, SE=meanSE,
                                        leastSigDiff=leastSigDiff,
                                        tukeysHSD=tukeysHSD))
        valueRes <- rbind(valueRes, res)
      }
    }#END go through all the trials
  }

  tableReportParms <- sapply(traitVec,
                             FUN=function(trait) analyzeTrait(trait, valueRes))

  # If trials had replicated data, they also have trial-specific LSD and HSD
  # Add these to the tableReportParms.  This is pretty janky...
  addLSDHSDtoTRP <- function(trait){
    stdErrResTrt <- stdErrRes[stdErrRes[,"trait"] == trait, ,drop=F]
    trpPlus <- c(tableReportParms[,trait],
                 list(trialLSD=stdErrResTrt[,"leastSigDiff"],
                      trialHSD=stdErrResTrt[,"tukeysHSD"]))
    return(trpPlus)
  }
  tableReportParms <- sapply(colnames(tableReportParms), addLSDHSDtoTRP)

  return(tableReportParms)
}

# Process one trial
# Output: 5-column data.frame with
# trait, trial, lineName, value, SE
# if the trial only has one value per line then SE is NA
processOneTrial <- function(trait, trial, data){
  data <- data[data$trial == trial,]
  data <- data[data$trait == trait,]
  nLines <- data$lineName |> unique() |> length()
  if (nrow(data) > nLines*1.2){ # Arbitrary: want at least 20% p-replication
    # There is replication => analyze and get lsmeans
    toReturn <- fitLMinTrial(data)
    toReturn$trait <- trait
    toReturn$trial <- trial
    toReturn <- toReturn[, c("trait", "trial", "lineName", "value", "SE", "df")]
  } else{
    # There is no replication. Use tapply in case of partial replication
    meanValue <- tapply(data$value, data$lineName, mean, simplify=T)
    toReturn <- data.frame(trait=trait, trial=trial, lineName=names(meanValue),
                           value=c(meanValue), SE=NA, df=NA)
  }
  return(toReturn)
}

# The trial has plot level data. We want one value per line
# per trial. That will be the LSmean. Also return the SE of the LSmean to
# combine trials.
fitLMinTrial <- function(data){
  fitTrialLM <- lm(value ~ lineName, data=data)
  trialLSmeans <- summary(lsmeans(fitTrialLM, "lineName", rg.limit = 500000))
  colnames(trialLSmeans)[colnames(trialLSmeans) == "lsmean"] <- "value"
  return(trialLSmeans)
}

# Once you have a data.frame where there is one value per lineName per trial
# you call this function
fitLMbyTrait <- function(trait, data){
  # Determine if there are variable std errs
  stdErrSD <- sd(data$SE, na.rm=T)
  if (is.na(stdErrSD)) stdErrSD <- 0
  if (stdErrSD == 0){
    # It was not possible to calculate trial SE (no replication)
    fitLM <- lm(value ~ trial + lineName, data=data)
  } else{
    # Different trials have different SE so use that as a weighting factor
    data$SE[is.na(data$SE)] <- mean(data$SE, na.rm=T)
    fitLM <- lm(value ~ trial + lineName, weights = 1/SE^2, data=data)
  }
  return(fitLM)
}

calcLSmeanParms <- function(fitLM){
  lineLSmeans <- summary(lsmeans(fitLM, "lineName", rg.limit = 500000))
  meanSE <- mean(lineLSmeans$SE)
  meanDF <- mean(lineLSmeans$df)
  leastSigDiff <- sqrt(2)*meanSE*qt(1 - 0.025, meanDF)
  # Tukey is already two-sided
  tukeysHSD <- meanSE*qtukey(1 - 0.05, nrow(lineLSmeans), meanDF)
  trialLSmeans <- summary(lsmeans(fitLM, "trial", rg.limit = 500000))
  return(list(lsmeans=lineLSmeans$lsmean, leastSigDiff=leastSigDiff, tukeysHSD=tukeysHSD, trialNames=levels(trialLSmeans$trial), trialMeans=trialLSmeans$lsmean, fitLM=fitLM))
}

analyzeTrait <- function(trait, oneCol){
  oneCol <- oneCol[oneCol$trait == trait,]
  nTrials <- oneCol$trial |> unique() |> length()
  if (nTrials == 1){
    # Hack: make dummy fitLM to report data back
    fitLM <- list()
    fitLM$xlevels <- list()
    fitLM$xlevels$lineName <- oneCol$lineName |> as.character() |>
      unique() |> sort()
    fitLM$model <- oneCol
    toReturn <- list(lsmeans=oneCol$value, leastSigDiff=NA, tukeysHSD=NA,
                  trialNames=unique(oneCol$trial),
                  trialMeans=mean(oneCol$value), fitLM=fitLM)
  } else{
    toReturn <- fitLMbyTrait(trait, oneCol) |> calcLSmeanParms()
  }
  return(toReturn)
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