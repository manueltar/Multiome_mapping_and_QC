.libPaths()
.libPaths(new = c("/home/manuel.tardaguila/conda_envs/multiome_NEW_downstream_analysis/lib/R/library"))
.libPaths()
# sessionInfo()
Sys.setenv(RETICULATE_PYTHON="/home/manuel.tardaguila/conda_envs/multiome_NEW_downstream_analysis/bin/python")

suppressMessages(library(Seurat))
suppressMessages(library(Signac))
suppressMessages(library(dplyr)) 
suppressMessages(library(ggplot2)) 
suppressMessages(library(Matrix)) 
suppressMessages(library(data.table)) 
suppressMessages(library(ggpubr)) 
suppressMessages(library(ggplot2))
suppressMessages(library(pheatmap))
suppressMessages(library("optparse"))
suppressMessages(library(BSgenome.Hsapiens.NCBI.GRCh38))
suppressMessages(library(BSgenome.Hsapiens.UCSC.hg38))


opt = NULL

options(warn = 0)


data_wrangling = function(option_list)
{
  
  opt_in = option_list
  opt <<- option_list
  
  cat("All options:\n")
  printList(opt)
  

  #### READ and transform type ----
  
  type = opt$type
  
  cat("TYPE_\n")
  cat(sprintf(as.character(type)))
  cat("\n")
  
  #### READ and transform out ---- "DE_results_without_time_as_a_covariate_NEW_METHOD_only_padj_less_0.05.tsv"
  
  out = opt$out
  
  cat("out_\n")
  cat(sprintf(as.character(out)))
  cat("\n")
  
  #### READ SIG ---- "DE_results_without_time_as_a_covariate_NEW_METHOD_only_padj_less_0.05.tsv"
  
  SIG<-as.data.frame(read.table(file=opt$SIG, sep="\t", header=T), stringsAsFactors=F)
  
  cat("SIG\n")
  str(SIG)
  cat("\n")
 
  DE_genes<-unique(SIG$gene)
  
  cat("DE_genes\n")
  str(DE_genes)
  cat("\n")
  
 
  #### READ adata ----
  
  adata<-readRDS(file=opt$adata)
  

  # cat("adata_0\n")
  # cat(str(adata))
  # cat("\n")
 
  # Set ATAC as assay ----------------------
 
  DefaultAssay(adata)<-'ATAC'
  
  # Do RegionStats ----------------------
  
  adata <- RegionStats(adata, genome = BSgenome.Hsapiens.UCSC.hg38, assay='ATAC')
  
  
  adata <- LinkPeaks(
    object = adata,
    peak.assay = "ATAC",
    expression.assay = "SCT",
    genes.use = DE_genes)
  
  
  ##################### Use the result -------------
  
  links = Links(adata)
  lf = as.data.frame(links)
  colnames(lf)[which(colnames(lf) == 'peak')]<-'Peak_ID'
  colnames(lf)[which(colnames(lf) == 'gene')]<-'Symbol'
  
  cat("lf_0\n")
  cat(str(lf))
  cat("\n")
  
  

  Links_Peaks_to_assigned_genes<-lf
  
  Links_Peaks_to_assigned_genes$Minus_logpval<-round(-1*log10(Links_Peaks_to_assigned_genes$pvalue),2)
  
  cat("Links_Peaks_to_assigned_genes_0\n")
  cat(str(Links_Peaks_to_assigned_genes))
  cat("\n")
  cat(str(unique(Links_Peaks_to_assigned_genes$gene)))
  cat("\n")
  cat(str(unique(Links_Peaks_to_assigned_genes$Peak_ID)))
  cat("\n")
  
  gr_Links <- GRanges(
    seqnames = as.character(gsub("^chr","",Links_Peaks_to_assigned_genes$seqnames)),
    name2=as.character(Links_Peaks_to_assigned_genes$Peak_ID),
    name3=as.numeric(Links_Peaks_to_assigned_genes$zscore),
    name4=as.numeric(Links_Peaks_to_assigned_genes$Minus_logpval),
    ranges=IRanges(
      start=as.numeric(Links_Peaks_to_assigned_genes$start),
      end=as.numeric(Links_Peaks_to_assigned_genes$end),
      name=paste('Link',as.character(Links_Peaks_to_assigned_genes$seqnames),
                 as.character(Links_Peaks_to_assigned_genes$start),
                 as.character(Links_Peaks_to_assigned_genes$end),                                   
                 sep='_')))
  
  # cat("gr_Links_0\n")
  # cat(str(gr_Links))
  # cat("\n")
  
  ALL_Linked_Peaks<-Links_Peaks_to_assigned_genes$Peak_ID
  
  gr_Linked_Peaks <- GRanges(
    seqnames = as.character(gsub("^chr","",gsub("-.+$","",ALL_Linked_Peaks))),  
    ranges=IRanges(
      start=as.integer(gsub("-.+$","",gsub("^[^-]+-","",ALL_Linked_Peaks))), 
      end=as.integer(gsub("^[^-]+-[^-]+-","",ALL_Linked_Peaks)),
      name=paste("Region", Links_Peaks_to_assigned_genes$Symbol, sep="__")))
  
  # cat("gr_Linked_Peaks_0\n")
  # cat(str(gr_Linked_Peaks))
  # cat("\n")
  
  ######### Append all sets of peaks of interest --------------
  
  gr_Peaks_DEF<-gr_Linked_Peaks
  
  Peaks_DEF_df <- unique(data.frame(chr=as.character(seqnames(gr_Peaks_DEF)),
                                    start=as.integer(start(gr_Peaks_DEF)),
                                    end=as.integer(end(gr_Peaks_DEF)), stringsAsFactors = F))
  
  Peaks_DEF_df$chr<-paste('chr',Peaks_DEF_df$chr,sep='')
  
  Peaks_DEF_df$Peak_ID<-paste(Peaks_DEF_df$chr,Peaks_DEF_df$start,Peaks_DEF_df$end,sep='-')
  
  cat("Peaks_DEF_df_0\n")
  cat(str(Peaks_DEF_df))
  cat("\n")
  
  ########### save and classify the new peaks with the next Rscript -------------
  
  setwd(out)
  
  saveRDS(Peaks_DEF_df, file="ALL_PoI.rds")
  
  saveRDS(Links_Peaks_to_assigned_genes, file ="Linked_peak_to_selected_genes.rds")
  write.table(Links_Peaks_to_assigned_genes, file ="Linked_peak_to_selected_genes.tsv",sep="\t",quote=F, row.names = F)
  
  

}


printList = function(l, prefix = "    ") {
  list.df = data.frame(val_name = names(l), value = as.character(l))
  list_strs = apply(list.df, MARGIN = 1, FUN = function(x) { paste(x, collapse = " = ")})
  cat(paste(paste(paste0(prefix, list_strs), collapse = "\n"), "\n"))
}



#### main script ----

main = function() {
  cmd_line = commandArgs()
  cat("Command line:\n")
  cat(paste(gsub("--file=", "", cmd_line[4], fixed=T),
            paste(cmd_line[6:length(cmd_line)], collapse = " "),
            "\n\n"))
  option_list <- list(
    make_option(c("--adata"), type="character", default=NULL, 
                metavar="type", 
                help="Path to tab-separated input file listing regions to analyze. Required."),
    make_option(c("--SIG"), type="character", default=NULL, 
                metavar="type", 
                help="Path to tab-separated input file listing regions to analyze. Required."),
    make_option(c("--type"), type="character", default=NULL, 
                metavar="type", 
                help="Path to tab-separated input file listing regions to analyze. Required."),
    make_option(c("--out"), type="character", default=NULL, 
                metavar="type", 
                help="Path to tab-separated input file listing regions to analyze. Required.")
  )
  parser = OptionParser(usage = "140__Rscript_v106.R
                        --subset type
                        --TranscriptEXP FILE.txt
                        --cadd FILE.txt
                        --ncboost FILE.txt
                        --type type
                        --out filename",
                        option_list = option_list)
  opt <<- parse_args(parser)
  
  data_wrangling(opt)
 

}


###########################################################################

system.time( main() )
  