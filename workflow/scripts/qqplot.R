#!/usr/bin/env Rscript

packs <- c("qqman","optparse","data.table","R.utils")


for (p in packs) {
  if( !require(p, character.only = T)) {
    print(p)
    install.packages( p,  repos = c(CRAN = "http://cran.r-project.org") )
  }
}

option_list = list(
  make_option(c("-f", "--file"), type="character", default=NULL,
              help="dataset file name", metavar="character"),
  make_option(c("-o", "--out"), type="character",
              help="output file name [default= %default]", metavar="character"),
  make_option(c("-c","--chrcol"), type="character", default="CHR",
              help="chromosome column [default= %default]", metavar="character"),
  make_option(c("-p","--pval_col"), type="character", default="P",
              help="pvalue column [default= %default]. This can be a comma separated list and plots will be generated for each of these", metavar="character"),
  make_option(c("-b","--bp_col"), type="character", default="BP",
              help="bp column [default= %default]", metavar="character"),
  make_option(c("-l","--loglog_pval"), type="integer", default=10,
              help="-log10 p-val threshold for using log-log scale in manhattan plot [default= %default]", metavar="integer"),
  make_option(c("-m","--minrep_col"), type="character",
              help="if given then chr:bp:ref:alt identifier assumed and chr and bp are read from there [default= %default]", metavar="character")
);

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser, positional_arguments=0);

# file="../GWAS/REGENIE_OUT_STEP2_chr1_pheno.regenie"
# bp_col="GENPOS"
# chr_col="CHROM"
# pcols =c("LOG10P")

file <- opt$options$file
print(paste("reading file:", file))

data <- fread(file, header=T)


options(bitmapType='cairo')

print(str(opt))
bp_col <- opt$options$bp_col
chr_col <- opt$options$chrcol

print(summary(data))
print( summary( data[[chr_col]] ) )
#colnames(data) <- toupper( colnames(data) )

pcols <- unlist(strsplit(opt$options$pval_col,","))

output_prefix=file

if( !is.null(opt$options$out)) {
  output_prefix=opt$options$out
}


if(! is.null(opt$options$minrep_col ) ) {
    print("getting BP and CHR from minrepid")
    split <- strsplit(as.character(data[[opt$options$minrep_col]]), ":")
    data[[bp_col]] <- unlist( lapply( split, function(x) as.numeric(x[2]) ))
    data[[chr_col]] <- unlist( lapply( split, function(x) x[1] ))
}

print(append(pcols,c(bp_col,chr_col)))

if( any( ! append(pcols,c(bp_col,chr_col)) %in% colnames(data)   )) {
  stop( paste0("All required columns do not exist in the data: ", paste(pcols,sep=",", collapse=""),",", bp_col, ",",chr_col,  collapse="" ))
}


print(summary(as.factor(data[[chr_col]])))

data[[chr_col]] <- gsub("chr","",data[[chr_col]])
data[[chr_col]] <- gsub("X|chrX","23",data[[chr_col]])
data[[chr_col]] <- gsub("Y|chrY","24",data[[chr_col]])
data[[chr_col]] <- gsub("MT|chrMT|M|chrM","25",data[[chr_col]])

data[[chr_col]] <- as.numeric(data[[chr_col]])
data <- data[ !is.na(data[[chr_col]]) ]

quants <- c(0.7,0.5,0.456,0.1,0.01, 0.001)



for( pcol in pcols) {
  data[[pcol]]<- 10^(-data[[pcol]])
  subdata <- data[ !is.na(data[[pcol]]) & is.numeric( data[[pcol]]  ) ]
  
  lambda  <- round(  quantile(  (qchisq(1-subdata[[pcol]], 1) ), probs=quants ) / qchisq(quants,1), 3)
  png( paste(output_prefix,"_", pcol ,"_qqplot.png", sep="" ))
  qq(subdata[[pcol]], main=paste("\nlambda ", quants, ": ", lambda, sep="" ) )
  dev.off()
  sink( paste(output_prefix,"_",  pcol ,"_qquantiles.txt", sep="" ) )
  cat( paste( quants, ":", lambda, sep=""))
  sink()
  
  print("subsetting p-vals < 0.01 for manhattan...")
  
  subdata <- subdata[ subdata[[pcol]]<0.01 & subdata[[pcol]]>0 ]
  print( paste0("Plotting manhattan with ", nrow(subdata), " variants") )
  print( summary(subdata[[pcol]] ))
  png( paste(output_prefix,"_",pcol,"_manhattan.png", sep=""), width=1000, height=400)
  logs <- -log10(subdata[[pcol]])
  
  manhattan( subdata , chr=chr_col, bp=bp_col, p=pcol,snp="ID", ylim=c( 2,max(logs)+1)  )
  dev.off()
  
  print("!!!!!!!!!!!!!!!!!!!!!!!")
  
  print("plotting log-log manhattan")
  loglog_p <- opt$options$loglog_pval
  logs <- ifelse(logs < loglog_p, logs, loglog_p * log10(logs) / log10(loglog_p))
  subdata[["p_scaled"]] <- 10^(-logs)
  tick_pos <- round(seq(1, max(logs), length.out=round(max(logs))))
  tick_lab <- sapply(tick_pos, function(pos) { round(ifelse(pos < loglog_p, pos, loglog_p^(pos/loglog_p))) })
  png( paste(output_prefix,"_",pcol,"_manhattan_loglog.png", sep=""), width=1000, height=400)
  manhattan( subdata, chr=chr_col, bp=bp_col, p="p_scaled", snp="ID", ylim=c( 2,max(logs)+1), yaxt="n")
  axis(2, at = tick_pos, labels=tick_lab, las=2)
  dev.off()
}


