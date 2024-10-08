library(tidyverse)
library(optparse)

option_list = list(
  make_option(c("-a", "--miss_case"), type="character", default="results/pre_imputation_QC/Geno05_SCRSex_VCR_case.lmiss"),
  make_option(c("-b", "--miss_cont"), type="character", default="results/pre_imputation_QC/Geno05_SCRSex_VCR_con.lmiss"),
  make_option(c("-c", "--hwe_all"), type="character", default="results/pre_imputation_QC/Geno05_SCRSex_VCR_all.hwe"),
  make_option(c("-d", "--hwe_female"), type="character", default="results/pre_imputation_QC/Geno05_SCRSex_VCR_female.hwe"),
  make_option(c("-m", "--miss_diff"), type="numeric", default= 0.02),
  make_option(c("-p","--non_x_up"), type= "numeric", default= 1e-06, help="p-value for 'UNAFF' test for non X-chr"),
  make_option(c("-q","--non_x_ap"), type= "numeric", default= 1e-10, help="p-value for 'AFF' test for non X-chr"),
  make_option(c("-x","--x_ap"), type= "numeric", default= 1e-06, help="p-value for 'ALL' test for X-chr(female)"),
  make_option(c("-o", "--outfile"), type="character", default="results/pre_imputation_QC/remove_missingness_hwe.txt")
)
opt = parse_args(OptionParser(option_list=option_list))

miss_case=read.table(file = opt$miss_case, sep="", header=T)
miss_cont=read.table(file = opt$miss_cont, sep="", header=T)
hwe_all=read.table(file = opt$hwe_all, sep="", header=T)
hwe_female=read.table(file = opt$hwe_female, sep="", header=T)
md<- opt$miss_diff
p1<- opt$non_x_up
p2<- opt$non_x_ap
p3<- opt$x_ap

# missing difference:
colnames(miss_case)<-paste0(colnames(miss_case), "_case")
missingness_merged<-miss_cont %>%
  left_join(miss_case, by=c("SNP"="SNP_case"))

missingness_merged<-missingness_merged%>%
  mutate(miss_diff=abs(F_MISS-F_MISS_case))

missingness_exclude<-missingness_merged %>%
  filter(miss_diff>md)

print("Number of SNPs to exclude because of missingness difference:")
print(nrow(missingness_exclude))

#HWE:
hwe_non_x_exclude<-hwe_all %>%
  filter(CHR!=23)%>%
  filter( (TEST=="UNAFF" & P<p1 ) |
          (TEST=="AFF" & P<p2) )

hwe_x_exclude<-hwe_female %>%
  filter(CHR==23)%>%
  filter(TEST=="ALL" & P<p3)

hwe_exclude<-rbind(
  hwe_non_x_exclude,
  hwe_x_exclude
)

print("Number of SNPs to exclude because of HWE:")
print(nrow(hwe_exclude))

# save
snps_to_exclude=rbind(
  missingness_exclude %>% select(SNP),
  hwe_exclude %>% select(SNP) )

write_tsv(x=snps_to_exclude,
      file=opt$outfile,
      col_names=F)
