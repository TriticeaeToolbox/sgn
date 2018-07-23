
##SNOPSIS

#Qtl analysis based on rqtl.


##AUTHOR
## Isaak Y Tecle (iyt2@cornell.edu)


options(echo = FALSE)

library(qtl)

allargs <- commandArgs()

infile   <- grep("infile_list", allargs, value=TRUE)
outfile  <- grep("outfile_list", allargs, value=TRUE)

infile   <- scan(infile, what="character")
statfile <- grep("stat", infile, value=TRUE)
             
##### stat files
statfiles <- scan(statfile, what="character")

###### QTL mapping method ############
qtlmethodfile <- grep("stat_qtl_method", statfiles, value=TRUE)
qtlmethod <- scan(qtlmethodfile, what="character", sep="\n")

if (qtlmethod == "Maximum Likelihood") {
  qtlmethod <- c("em")
} else if (qtlmethod == "Haley-Knott Regression") {
  qtlmethod <- c("hk")
} else if (qtlmethod == "Multiple Imputation") {
  qtlmethod <- c("imp")
} else if (qtlmethod == "Marker Regression") {
  qtlmethod <- c("mr")
}

###### QTL model ############
qtlmodelfile <- grep("stat_qtl_model",  statfiles, value=TRUE)
qtlmodel <- scan(qtlmodelfile, what="character", sep="\n")

if (qtlmodel == "Single-QTL Scan") {
  qtlmodel <- c("scanone")
} else if  (qtlmodel == "Two-QTL Scan") {
  qtlmodel<-c("scantwo")
}

###### permutation############
userpermufile  <- grep("stat_permu_test", statfiles, value=TRUE)
userpermuvalue <- scan(userpermufile, what="numeric", dec= ".", sep="\n")

if (userpermuvalue == "None") {
  userpermuvalue<-c(0)
}

userpermuvalue <- as.numeric(userpermuvalue)

#####for test only
#userpermuvalue<-c(100)
#####


######genome step size############
stepsizefile <- grep("stat_step_size",  statfiles, value=TRUE)

stepsize <- scan(stepsizefile, what="numeric", dec = ".", sep="\n")

if (qtlmethod == 'mr') {
    stepsize <- c(0)
} else if (qtlmethod != 'mr' & stepsize == "zero") {
      stepsize <- c(0)
  }

stepsize <- as.numeric(stepsize)

######genotype calculation method############
genoprobmethodfile <- grep("stat_prob_method", statfiles, value=TRUE)

genoprobmethod <- scan(genoprobmethodfile, what="character", dec=".", sep="\n")


########No. of draws for sim.geno method###########
drawsnofile <- c()
drawsno <- c()
if (qtlmethod == 'imp') {
    if (is.null(grep("stat_no_draws", statfiles))==FALSE) {
        drawsnofile <- grep("stat_no_draws", statfiles, value=TRUE)
    }

    if (is.null(drawsnofile)==FALSE) {
        drawsno <- scan(drawsnofile, what="numeric", dec = ".", sep="\n")
        drawsno <- as.numeric(drawsno)
      }
  }
########significance level for genotype
#######probablity calculation
genoproblevelfile <- grep("stat_prob_level", statfiles, value=TRUE)
genoproblevel     <- scan(genoproblevelfile, what="numeric", dec = ".", sep="\n")

if (qtlmethod == 'mr') {
    if (is.logical(genoproblevel) == FALSE) {
        genoproblevel <- c(0)
    }
    
    if (is.logical(genoprobmethod) ==FALSE) {
        genoprobmethod <- c('Calculate')
      }
  }

genoproblevel <- as.numeric(genoproblevel)

########significance level for permutation test
permuproblevelfile <- grep("stat_permu_level", statfiles, value=TRUE)

permuproblevel <- scan(permuproblevelfile, what="numeric", dec = ".", sep="\n")

permuproblevel <- as.numeric(permuproblevel)

#########
cvtermfile <- grep("cvterm", infile, value=TRUE)

popidfile <- grep("popid", infile, value=TRUE)                 

genodata <- grep("genodata", infile, value=TRUE)                 

phenodata <- grep("phenodata", infile, value=TRUE)                 

permufile <- grep("permu", infile, value=TRUE)                 

crossfile <- grep("cross", infile, value=TRUE)

popid <- scan(popidfile, what="integer", sep="\n")

cross <- scan(crossfile,what="character", sep="\n")

popdata<-c()

if (cross == "f2")
{
  popdata <- read.cross("csvs",
                       genfile=genodata,
                       phefile=phenodata,
                       na.strings=c("NA", "-"),
                       genotypes=c("1", "2", "3", "4", "5"),
                       )

  popdata <-jittermap(popdata)
} else if (cross == "bc" | cross == "rilsib" | cross == "rilself") {
    
  popdata <- read.cross("csvs",
                       genfile=genodata,
                       phefile=phenodata,
                       na.strings=c("NA", "-"),
                       genotypes=c("1", "2"),                      
                       )

  popdata<-jittermap(popdata)
}  

if (cross == "rilself") {
    popdata<-convert2riself(popdata)
} else if (cross == "rilsib") {
    popdata<-convert2risib(popdata)  
}

#calculates the qtl genotype probablity at
#the specififed step size and probability level
genotypetype <- c()

if (genoprobmethod == "Calculate") {
    popdata <- calc.genoprob(popdata,
                           step=stepsize,
                           error.prob=genoproblevel
                           )
    genotypetype<-c('prob')
} else if (genoprobmethod == "Simulate") {
    popdata <- sim.geno(popdata,
                      n.draws=drawsno,
                      step=stepsize,
                      error.prob=genoproblevel,
                      stepwidth="fixed"
                        )
    
    genotypetype <- c('draws')
}

cvterm <- scan(cvtermfile, what="character") #reads the cvterm

cv <- find.pheno(popdata, cvterm)#returns the col no. of the cvterm

permuvalues <- scan(permufile, what="character")

permuvalue1 <- permuvalues[1]
permuvalue2 <- permuvalues[2]
permu <- c()

if (is.logical(permuvalue1) == FALSE) {
  if (qtlmodel == "scanone") {
    if (userpermuvalue == 0 ) {
      popdataperm <- scanone(popdata,
                             pheno.col=cv,
                             model="normal",
                             method=qtlmethod
                             )
      
    } else if (userpermuvalue != 0) {
        popdataperm <- scanone(popdata,
                               pheno.col=cv,
                               model="normal",
                               n.perm = userpermuvalue,
                               method=qtlmethod
                               )
      
        permu <- summary(popdataperm, alpha=permuproblevel)
    }
  } else if (qtlmethod != "mr") {
    if (qtlmodel == "scantwo") {
      if (userpermuvalue == 0 ) {
        popdataperm <- scantwo(popdata,
                               pheno.col=cv,
                               model="normal",
                               method=qtlmethod
                               )
      } else if (userpermuvalue != 0) {
          popdataperm <- scantwo(popdata,
                                 pheno.col=cv,
                                 model="normal",
                                 n.perm=userpermuvalue,
                                 method=qtlmethod
                                 )
          
        permu <- summary(popdataperm, alpha=permuproblevel)
    
      }
    }
  }
}

##########set the LOD cut-off for singificant qtls ##############
LodThreshold <- c()

if(is.null(permu) == FALSE) {
  LodThreshold <- permu[1,1]
}
##########QTL EFFECTS ##############

chrlist <- c("chr1")

for (no in 2:12) {
    chr <- paste("chr", no, sep="")
    
    chrlist <- append(chrlist, chr)
}

chrdata <- paste(cvterm, popid, "chr1", sep="_")

chrtest <- c("chr1")

for (ch in chrlist) {
  if (ch=="chr1") {
    chrdata <- paste(cvterm, popid, ch, sep="_")
  } else {
    n <- paste(cvterm, popid, ch, sep="_")
    chrdata <- append(chrdata, n)   
  }
} 

chrno <- 1

datasummary <- c()
confidenceints <- c()
lodconfidenceints <- c()
QtlChrs <- c()
QtlPositions <- c()
QtlLods <- c()

for (i in chrdata) {  
  filedata <- paste(cvterm, popid, chrno, sep="_")
  filedata <- paste(filedata,"txt",sep=".")
  
  i <- scanone(popdata,
               chr=chrno,
               pheno.col=cv,
               model = "normal",
               method= qtlmethod
               )
  
  position <- max(i,chr=chrno)
  
  p <- position[["pos"]]
  LodScore <- position[["lod"]]
  QtlChr <- levels(position[["chr"]])

      if ( is.null(LodThreshold)==FALSE ) {
          if (LodScore >=LodThreshold ) {
              QtlChrs <- append(QtlChrs, QtlChr) 
              QtlLods <- append(QtlLods, LodScore)  
              QtlPositions <- append(QtlPositions, round(p, 0))
            }
        }
     
  peakmarker <- find.marker(popdata, chr=chrno, pos=p)
 
  lodpeakmarker <- i[peakmarker, ]
  
  lodconfidenceint <- bayesint(i, chr=chrno, prob=0.95, expandtomarkers=TRUE)

  if (is.na(lodconfidenceint[peakmarker, ])){
      lodconfidenceint <- rbind(lodconfidenceint, lodpeakmarker)
    }
  
  peakmarker <- c(chrno, peakmarker)
  
  if (chrno==1) { 
    datasummary <- i
    peakmarkers <- peakmarker
    lodconfidenceints <- lodconfidenceint
  }
  
  if (chrno > 1 ) {
      datasummary <- rbind(datasummary, i)
      peakmarkers <- rbind(peakmarkers, peakmarker)
      lodconfidenceints <- rbind(lodconfidenceints, lodconfidenceint)
  }

chrno <- chrno + 1;

}

##########QTL EFFECTS ##############
 ResultDrop <- c()
 ResultFull <- c()
 Effects <- c()

if (is.null(LodThreshold) == FALSE) {
    if ( max(QtlLods) >= LodThreshold ) {
        QtlObj <- makeqtl(popdata,
                          QtlChrs,
                          QtlPositions,
                          what=genotypetype
                          )

        QtlsNo <- length(QtlPositions)
        Eq <- c("y~")

        for (i in 1:QtlsNo) {
                q <- paste("Q", i, sep="")
  
                if (i==1) {  
                    Eq <- paste(Eq, q, sep="")      
                  } else if (i>1) {
                      Eq <- paste(Eq, q, sep="*")    
                  }
              }
            
        QtlEffects <- try(fitqtl(popdata,
                                 pheno.col=cv,
                                 QtlObj,
                                 formula=Eq,
                                 method="hk",                   
                                 get.ests=TRUE
                                 )          
                          )
           
        if(class(QtlEffects) != 'try-error') {
               
                ResultModel <- attr(QtlEffects, "formula")
                Effects     <- QtlEffects$ests$ests
                QtlLodAnova <- QtlEffects$lod
                ResultFull  <- QtlEffects$result.full  
                ResultDrop  <- QtlEffects$result.drop
                  
                if (is.numeric(Effects)) {
                    Effects <- round(Effects, 2)
                }

                if (is.numeric(ResultFull)) {
                    ResultFull <- round(ResultFull,2)
                }

                if (is.numeric(ResultDrop)) {
                    ResultDrop<-round(ResultDrop, 2)
                }
            }
    }
}

##########creating vectors for the outfiles##############

outfiles <- scan(file=outfile, what="character")

qtlfile           <- grep("qtl_summary", outfiles, value=TRUE)
peakmarkersfile   <- grep("peak_marker", outfiles, value=TRUE)
confidencelodfile <- grep("confidence", outfiles, value=TRUE)
QtlEffectsFile    <- grep("qtl_effects", outfiles, value=TRUE)
VariationFile     <- grep("explained_variation", outfiles, value=TRUE)

##### writing outputs to their respective files

write.table(datasummary,
            file=qtlfile,
            sep="\t",
            col.names=NA,
            quote=FALSE,
            append=FALSE
            )

write.table(peakmarkers,
            file=peakmarkersfile,
            sep="\t",
            col.names=NA,
            quote=FALSE,
            append=FALSE
            )

write.table(lodconfidenceints,
            file=confidencelodfile,
            sep="\t",
            col.names=NA,
            quote=FALSE,
            append=FALSE
            )

if (is.null(ResultDrop)==FALSE) {
  write.table(ResultDrop,
              file=VariationFile,
              sep="\t",
              col.names=NA,
              quote=FALSE,
              append=FALSE
              )
} else {
  if (is.null(ResultFull)==FALSE) {
      write.table(ResultFull,
              file=VariationFile,
              sep="\t",
              col.names=NA,
              quote=FALSE,
              append=FALSE
              )
    }
}

write.table(Effects,
            file=QtlEffectsFile,
            sep="\t",
            col.names=NA,
            quote=FALSE,
            append=FALSE
            )

write.table(permu,
            file=permufile,
            sep="\t",
            col.names=NA,
            quote=FALSE,
            append=FALSE
                )

q(runLast = FALSE)
