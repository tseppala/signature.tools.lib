# extended/adapted from Xueqing Zou's code by Andrea Degasperi, 2020

# required packages: Biostrings

# requires columns Sample, Chrom, Pos, Ref, Alt, with Ref and Alt of length 1
# returns both list of DNVs and DNV catalogues

#' Build a Dinucleotide Variants Catalogue from SNVs
#' 
#' This function takes as input a list of single nucleotide variants (SNVs),
#' and computes a list of dinucleotide variants (DNVs) finding which SNVs
#' are next to each other. It the returns the annotated DNVs and the DNV catalogues.
#' The catalogues are in Zou's style.
#' 
#' @param snvtab requires columns Sample, Chrom, Pos, Ref, Alt, with Ref and Alt of length 1
#' @return list of DNVs and DNV catalogue
#' @references J. E. Kucab, X. Zou, S. Morganella, M. Joel, A. S. Nanda, E. Nagy, C. Gomez, A. Degasperi, R. Harris, S. P. Jackson, V. M. Arlt, D. H. Phillips, S. Nik-Zainal. A Compendium of Mutational Signatures of Environmental Agents. Cell, https://doi.org/10.1016/j.cell.2019.03.001, 2019.
#' @export
snvTabToDNVcatalogue <- function(snvtab){
  
  mutationTypes <- c("AA>CC","AA>CG","AA>CT","AA>GC","AA>GG","AA>GT","AA>TC","AA>TG","AA>TT",
         "AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
         "AG>CA","AG>CC","AG>CT","AG>GA","AG>GC","AG>GT","AG>TA","AG>TC","AG>TT",
         "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
         "CA>AC","CA>AG","CA>AT","CA>GC","CA>GG","CA>GT","CA>TC","CA>TG","CA>TT",
         "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
         "CG>AA","CG>AC","CG>AT","CG>GA","CG>GC","CG>TA",
         "GA>AC","GA>AG","GA>AT","GA>CC","GA>CG","GA>CT","GA>TC","GA>TG","GA>TT",
         "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
         "TA>AC","TA>AG","TA>AT","TA>CC","TA>CG","TA>GC")
  
  # Ludmil's channels
  # mutationTypes <- c("AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
  #                    "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
  #                    "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
  #                    "CG>AT","CG>GC","CG>GT","CG>TA","CG>TC","CG>TT",
  #                    "CT>AA","CT>AC","CT>AG","CT>GA","CT>GC","CT>GG","CT>TA","CT>TC","CT>TG",
  #                    "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
  #                    "TA>AT","TA>CG","TA>CT","TA>GC","TA>GG","TA>GT",
  #                    "TC>AA","TC>AG","TC>AT","TC>CA","TC>CG","TC>CT","TC>GA","TC>GG","TC>GT",
  #                    "TG>AA","TG>AC","TG>AT","TG>CA","TG>CC","TG>CT","TG>GA","TG>GC","TG>GT",
  #                    "TT>AA","TT>AC","TT>AG","TT>CA","TT>CC","TT>CG","TT>GA","TT>GC","TT>GG")
  
  sample_list <- unique(snvtab$Sample)
  DNV_catalogue <- data.frame(row.names = mutationTypes,stringsAsFactors = F)
  DNV_table <- NULL
  for (s in sample_list){
    # for debug: s <- sample_list[1]
    samplesubs <- snvtab[snvtab$Sample==s,,drop=F]
    allchroms <- unique(samplesubs$Chrom)
    sample_DNVs <- NULL
    for (chrom in allchroms){
      # for debug: chrom <- allchroms[1]
      # search for DNV in each chromosome
      chromsubs <- samplesubs[samplesubs$Chrom==chrom,,drop=F]
      # order by position
      chromsubs <- chromsubs[order(chromsubs$Pos),,drop=F]
      # now annotate
      chromsubs$Pos_nextSNV <- c(chromsubs$Pos[-1],0)
      chromsubs$dist_nextSNV <- chromsubs$Pos-chromsubs$Pos_nextSNV
      chromsubs$Ref_nextSNV <- c(chromsubs$Ref[-1],"N")
      chromsubs$Alt_nextSNV <- c(chromsubs$Alt[-1],"N")
      # now find the DNVs
      dinuc_index <- which(chromsubs$dist_nextSNV==-1)
      chromsubs <- chromsubs[dinuc_index,,drop=F]
      if (nrow(chromsubs)>0){
        # if some DNVs are found, annotate
        chromsubs$dinuc_Ref <- paste0(chromsubs$Ref,chromsubs$Ref_nextSNV)
        chromsubs$dinuc_Alt <- paste0(chromsubs$Alt,chromsubs$Alt_nextSNV)
        chromsubs$dinuc_mutation <- paste0(chromsubs$dinuc_Ref,">",chromsubs$dinuc_Alt)
        # get reverse complement
        chromsubs$dinuc_Ref_rc <- as.character(Biostrings::reverseComplement(Biostrings::DNAStringSet(chromsubs$dinuc_Ref)))
        chromsubs$dinuc_Alt_rc <- as.character(Biostrings::reverseComplement(Biostrings::DNAStringSet(chromsubs$dinuc_Alt)))
        chromsubs$dinuc_mutation_rc <- paste0(chromsubs$dinuc_Ref_rc,">",chromsubs$dinuc_Alt_rc)
        # now check if the mutation is in the set of mutation types, otherwise use reverse complement
        isInMutTypes <- chromsubs$dinuc_mutation %in% mutationTypes
        chromsubs$dinuc_mutation_final <- sapply(1:nrow(chromsubs),function(x) {
            ifelse(isInMutTypes[x],chromsubs$dinuc_mutation[x],chromsubs$dinuc_mutation_rc[x])
          })
        sample_DNVs <- rbind(sample_DNVs,chromsubs)
      }
    }
    # add to final DNV table
    DNV_table <- rbind(DNV_table,sample_DNVs)
    
    #  now I have the sample DNVs, build also the catalogue
    if (is.null(sample_DNVs)){
      DNV_catalogue[,s] <- 0
    }else{
      countmuts <- table(sample_DNVs$dinuc_mutation_final)
      DNV_catalogue[,s] <- 0
      DNV_catalogue[names(countmuts),s] <- countmuts
    }
     
  }
  
  res <- list()
  res$DNV_catalogue <- DNV_catalogue
  res$DNV_table <- DNV_table
  return(res)
}


# requires columns Sample, Chrom, Pos, Ref, Alt, with Ref and Alt of length 2
# returns both list of DNVs and DNV catalogues

#' Build a Dinucleotide Variants Catalogue from DNVs list
#' 
#' This function takes as input a list of dinucleotide variants (DNVs). It then
#'annotates the DNVs and computes the DNV catalogues. The catalogues are in Zou's style.
#' 
#' @param snvtab requires columns Sample, Chrom, Pos, Ref, Alt, with Ref and Alt of length 2
#' @return list of annotated DNVs and DNV catalogue
#' @references J. E. Kucab, X. Zou, S. Morganella, M. Joel, A. S. Nanda, E. Nagy, C. Gomez, A. Degasperi, R. Harris, S. P. Jackson, V. M. Arlt, D. H. Phillips, S. Nik-Zainal. A Compendium of Mutational Signatures of Environmental Agents. Cell, https://doi.org/10.1016/j.cell.2019.03.001, 2019.
#' @export
dnvTabToDNVcatalogue <- function(dnvtab){
  
  mutationTypes <- c("AA>CC","AA>CG","AA>CT","AA>GC","AA>GG","AA>GT","AA>TC","AA>TG","AA>TT",
                     "AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
                     "AG>CA","AG>CC","AG>CT","AG>GA","AG>GC","AG>GT","AG>TA","AG>TC","AG>TT",
                     "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
                     "CA>AC","CA>AG","CA>AT","CA>GC","CA>GG","CA>GT","CA>TC","CA>TG","CA>TT",
                     "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
                     "CG>AA","CG>AC","CG>AT","CG>GA","CG>GC","CG>TA",
                     "GA>AC","GA>AG","GA>AT","GA>CC","GA>CG","GA>CT","GA>TC","GA>TG","GA>TT",
                     "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
                     "TA>AC","TA>AG","TA>AT","TA>CC","TA>CG","TA>GC")
  
  # Ludmil's channels
  # mutationTypes <- c("AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
  #                    "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
  #                    "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
  #                    "CG>AT","CG>GC","CG>GT","CG>TA","CG>TC","CG>TT",
  #                    "CT>AA","CT>AC","CT>AG","CT>GA","CT>GC","CT>GG","CT>TA","CT>TC","CT>TG",
  #                    "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
  #                    "TA>AT","TA>CG","TA>CT","TA>GC","TA>GG","TA>GT",
  #                    "TC>AA","TC>AG","TC>AT","TC>CA","TC>CG","TC>CT","TC>GA","TC>GG","TC>GT",
  #                    "TG>AA","TG>AC","TG>AT","TG>CA","TG>CC","TG>CT","TG>GA","TG>GC","TG>GT",
  #                    "TT>AA","TT>AC","TT>AG","TT>CA","TT>CC","TT>CG","TT>GA","TT>GC","TT>GG")
  
  sample_list <- unique(dnvtab$Sample)
  DNV_catalogue <- data.frame(row.names = mutationTypes,stringsAsFactors = F)
  DNV_table <- NULL
  for (s in sample_list){
    # for debug: s <- sample_list[1]
    sample_DNVs <- NULL
    sample_DNVs <- dnvtab[dnvtab$Sample==s,,drop=F]
    sample_DNVs$dinuc_mutation <- paste0(sample_DNVs$Ref,">",sample_DNVs$Alt)
    # get reverse complement
    sample_DNVs$Ref_rc <- as.character(Biostrings::reverseComplement(Biostrings::DNAStringSet(sample_DNVs$Ref)))
    sample_DNVs$Alt_rc <- as.character(Biostrings::reverseComplement(Biostrings::DNAStringSet(sample_DNVs$Alt)))
    sample_DNVs$dinuc_mutation_rc <- paste0(sample_DNVs$Ref_rc,">",sample_DNVs$Alt_rc)
    # now check if the mutation is in the set of mutation types, otherwise use reverse complement
    isInMutTypes <- sample_DNVs$dinuc_mutation %in% mutationTypes
    sample_DNVs$dinuc_mutation_final <- sapply(1:nrow(sample_DNVs),function(x) {
      ifelse(isInMutTypes[x],sample_DNVs$dinuc_mutation[x],sample_DNVs$dinuc_mutation_rc[x])
    })
    
    # add to final DNV table
    DNV_table <- rbind(DNV_table,sample_DNVs)
    
    #  now I have the sample DNVs, build also the catalogue
    if (is.null(sample_DNVs)){
      DNV_catalogue[,s] <- 0
    }else{
      countmuts <- table(sample_DNVs$dinuc_mutation_final)
      DNV_catalogue[,s] <- 0
      DNV_catalogue[names(countmuts),s] <- countmuts
    }
    
  }
  
  res <- list()
  res$DNV_catalogue <- DNV_catalogue
  res$DNV_table <- DNV_table
  return(res)
}

# Plot the double substitution profiles for all samples
plot_allsample_Dinucleotides_profile <- function(muttype_catalogue,colnum,h,w,outputname){
  
  muttype_catalogue$MutationType <- rownames(muttype_catalogue)
  muttype_catalogue$Ref <- substr(muttype_catalogue$MutationType,1,2)
  
  muts_basis_melt <- data.table::melt(muttype_catalogue,id=c("MutationType","Ref"))
  names(muts_basis_melt) <- c("MutationType","Ref","sample","count")
  
  mypalette <- c("#e6194b","#3cb44b","#ffe119","#0082c8","#f58231","#911eb4","#46f0f0","#f032e6","#d2f53c","#fabebe")
  library(ggplot2)
  pdf(file=outputname, onefile=TRUE,width=w,height=h)
  p <- ggplot(data=muts_basis_melt, aes(x=MutationType, y=count,fill=Ref,width=0.5))+ geom_bar(position="dodge", stat="identity")+xlab("Dinucleotide mutation type")+ylab("")
  #  p <- p+coord_cartesian(ylim=c(0, max(muttype_freq[,"freq"])))
  p <- p+scale_x_discrete(limits = as.character(muttype_catalogue$MutationType))
  p <- p+scale_fill_manual(values=mypalette)
  p <- p+theme(axis.text.x=element_text(angle=90, vjust=0.5,size=5,colour = "black"),
               axis.text.y=element_text(size=10,colour = "black"),
               axis.title.x = element_text(size=15),
               axis.title.y = element_text(size=15),
               plot.title = element_text(size=10),
               panel.grid.minor.x=element_blank(),
               panel.grid.major.x=element_blank(),
               panel.grid.major.y = element_blank(),
               panel.grid.minor.y = element_blank(),
               panel.background = element_rect(fill = "white"),
               panel.border = element_rect(colour = "black", fill=NA))
  p <- p+facet_wrap(~sample,ncol=colnum,scales = "free")
  print(p)
  dev.off()
}


#' Plot Dinucleotide Variant Signatures or Catalogues
#' 
#' Function to plot one or more DNV signatures or catalogues. 
#' 
#' @param signature_data_matrix matrix of signatures or catalogues, signatures as columns and channels as rows. You can use either Zou or Alexandrov Style and the function will recognise the rownames and plot accordingly
#' @param output_file set output file, should end with ".jpg" of ".pdf". If output_file==null, output will not be to a file, but will still run the plot functions. The option output_file==null can be used to add this plot to a larger output file.
#' @param plot_sum whether the sum of the channels should be plotted. If plotting signatures this should be FALSE, but if plotting sample catalogues, this can be set to TRUE to display the number of mutations in each sample.
#' @param overall_title set the overall title of the plot
#' @param mar set the margin of the plot
#' @export
plotDNVSignatures <- function(signature_data_matrix,
                              output_file = NULL,
                              plot_sum = TRUE,
                              overall_title = "",
                              add_to_titles = NULL,
                              mar=NULL){
  if(!is.null(output_file)) plottype <- substr(output_file,nchar(output_file)-2,nchar(output_file))
  # colnames(signature_data_matrix) <- sapply(colnames(signature_data_matrix),function(x) if (nchar(x)>30) paste0(substr(x,1,23),"...") else x)
  
  mutationTypesZou <- c("AA>CC","AA>CG","AA>CT","AA>GC","AA>GG","AA>GT","AA>TC","AA>TG","AA>TT",
                     "AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
                     "AG>CA","AG>CC","AG>CT","AG>GA","AG>GC","AG>GT","AG>TA","AG>TC","AG>TT",
                     "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
                     "CA>AC","CA>AG","CA>AT","CA>GC","CA>GG","CA>GT","CA>TC","CA>TG","CA>TT",
                     "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
                     "CG>AA","CG>AC","CG>AT","CG>GA","CG>GC","CG>TA",
                     "GA>AC","GA>AG","GA>AT","GA>CC","GA>CG","GA>CT","GA>TC","GA>TG","GA>TT",
                     "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
                     "TA>AC","TA>AG","TA>AT","TA>CC","TA>CG","TA>GC")
  mutationTypesAlexandrov <-    c("AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
                        "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
                        "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
                        "CG>AT","CG>GC","CG>GT","CG>TA","CG>TC","CG>TT",
                        "CT>AA","CT>AC","CT>AG","CT>GA","CT>GC","CT>GG","CT>TA","CT>TC","CT>TG",
                        "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
                        "TA>AT","TA>CG","TA>CT","TA>GC","TA>GG","TA>GT",
                        "TC>AA","TC>AG","TC>AT","TC>CA","TC>CG","TC>CT","TC>GA","TC>GG","TC>GT",
                        "TG>AA","TG>AC","TG>AT","TG>CA","TG>CC","TG>CT","TG>GA","TG>GC","TG>GT",
                        "TT>AA","TT>AC","TT>AG","TT>CA","TT>CC","TT>CG","TT>GA","TT>GC","TT>GG")
  
  if(all(rownames(signature_data_matrix)==mutationTypesZou)){
    catalogueType <- "Zou"
  }else if(all(rownames(signature_data_matrix)==mutationTypesAlexandrov)){
    catalogueType <- "Alexandrov"
  }else{
    message("Unknown DNV channels (rownames) style, please use NN>NN rownames in either Zou or Alexandrov style")
    exit(1)
  }
  
  if(catalogueType=="Zou"){
    muttypeslength <- c(9,9,9,6,9,9,6,9,6,6)
    mypalette <- c("#e6194b","#3cb44b","#ffe119","#0082c8","#f58231","#911eb4","#46f0f0","#f032e6","#d2f53c","#fabebe")
    muttypes <- c("AA>NN","AC>NN","AG>NN","AT>NN","CA>NN","CC>NN","CG>NN","GA>NN","GC>NN","TA>NN")
  }else if(catalogueType=="Alexandrov"){
    muttypeslength <- c(9,6,9,6,9,6,6,9,9,9)
    mypalette <- c(rgb(164,205,224,maxColorValue = 255),
                   rgb(31,119,182,maxColorValue = 255),
                   rgb(176,222,139,maxColorValue = 255),
                   rgb(50,160,43,maxColorValue = 255),
                   rgb(252,152,152,maxColorValue = 255),
                   rgb(227,33,29,maxColorValue = 255),
                   rgb(243,185,109,maxColorValue = 255),
                   rgb(250,125,0,maxColorValue = 255),
                   rgb(200,175,210,maxColorValue = 255),
                   rgb(105,60,155,maxColorValue = 255))
    muttypes <- c("AC>NN","AT>NN","CC>NN","CG>NN","CT>NN","GC>NN","TA>NN","TC>NN","TG>NN","TT>NN")
  }else{
    message("Unknown catalogue type.")
    exit(1)
  }
  
  rearr.colours <- c()
  for (i in 1:length(mypalette)) rearr.colours <- c(rearr.colours,rep(mypalette[i],muttypeslength[i]))

  nplotrows <- ceiling(ncol(signature_data_matrix)/3)
  if(!is.null(output_file)) {
    if(plottype=="jpg"){
      jpeg(output_file,width = 3*800,height = nplotrows*320,res = 220)
    }else if (plottype=="pdf"){
      pdf(output_file,width = 3*8,height = nplotrows*3.2,pointsize = 26)
    }
    par(mfrow = c(nplotrows, 3),oma=c(0,0,2,0))
  }
  for (pos in 1:ncol(signature_data_matrix)){
    if(is.null(mar)){
      par(mar=c(2,3,2,2))
    }else{
      par(mar=mar)
    }
    title <- colnames(signature_data_matrix)[pos]
    if (plot_sum) title <- paste0(title," (",round(sum(signature_data_matrix[,pos]))," DNVs)")
    if (!is.null(add_to_titles)) title <- paste0(title,"\n",add_to_titles[pos])
    xlabels <- rep("",nrow(signature_data_matrix))
    xlabels2 <- sapply(rownames(signature_data_matrix),function(x){
      strsplit(x,split = ">")[[1]][2]
    })
    
    b <- barplot(signature_data_matrix[,pos],
            main = title,
            #names.arg = row.names(signature_data_matrix),
            names.arg = xlabels,
            col=rearr.colours,
            beside = TRUE,
            las=2,
            cex.names = 1,border = NA,space = 0.2)
    par(xpd=TRUE)
    par(usr = c(0, 1, 0, 1))
    recttop <- -0.092
    rectbottom <- -0.21
    start1 <- 0.037
    endfinal <- 0.963
    gap <- (endfinal-start1)/nrow(signature_data_matrix)
    xpos2 <- start1 - gap/2 + 1:length(xlabels2)*gap
    text(x=xpos2,y = -0.04,label = xlabels2,srt=90,cex = 0.3)
    for (i in 1:length(mypalette)) {
      end1 <- start1+gap*muttypeslength[i]
      rect(start1, rectbottom, end1, recttop,col = mypalette[i],lwd = 0,border = NA)
      text(x =start1+(end1-start1)/2,y = -0.15,labels = muttypes[i],col = "black",font = 2,cex = 0.5)
      start1 <- end1
    }
    
    par(xpd=FALSE)
  }
  title(main = overall_title,outer = TRUE,cex.main = 2)
  if(!is.null(output_file)) dev.off()
}

plotDNVSignatures_withMeanSd <- function(signature_data_matrix,
                                         mean_matrix,
                                         sd_matrix,
                                         output_file = NULL,
                                         plot_sum = TRUE,
                                         overall_title = "",
                                         add_to_titles = NULL,
                                         mar=NULL){
  if(!is.null(output_file)) plottype <- substr(output_file,nchar(output_file)-2,nchar(output_file))
  # colnames(signature_data_matrix) <- sapply(colnames(signature_data_matrix),function(x) if (nchar(x)>30) paste0(substr(x,1,23),"...") else x)
  
  mutationTypesZou <- c("AA>CC","AA>CG","AA>CT","AA>GC","AA>GG","AA>GT","AA>TC","AA>TG","AA>TT",
                        "AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
                        "AG>CA","AG>CC","AG>CT","AG>GA","AG>GC","AG>GT","AG>TA","AG>TC","AG>TT",
                        "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
                        "CA>AC","CA>AG","CA>AT","CA>GC","CA>GG","CA>GT","CA>TC","CA>TG","CA>TT",
                        "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
                        "CG>AA","CG>AC","CG>AT","CG>GA","CG>GC","CG>TA",
                        "GA>AC","GA>AG","GA>AT","GA>CC","GA>CG","GA>CT","GA>TC","GA>TG","GA>TT",
                        "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
                        "TA>AC","TA>AG","TA>AT","TA>CC","TA>CG","TA>GC")
  mutationTypesAlexandrov <-    c("AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
                                  "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
                                  "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
                                  "CG>AT","CG>GC","CG>GT","CG>TA","CG>TC","CG>TT",
                                  "CT>AA","CT>AC","CT>AG","CT>GA","CT>GC","CT>GG","CT>TA","CT>TC","CT>TG",
                                  "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
                                  "TA>AT","TA>CG","TA>CT","TA>GC","TA>GG","TA>GT",
                                  "TC>AA","TC>AG","TC>AT","TC>CA","TC>CG","TC>CT","TC>GA","TC>GG","TC>GT",
                                  "TG>AA","TG>AC","TG>AT","TG>CA","TG>CC","TG>CT","TG>GA","TG>GC","TG>GT",
                                  "TT>AA","TT>AC","TT>AG","TT>CA","TT>CC","TT>CG","TT>GA","TT>GC","TT>GG")
  
  if(all(rownames(signature_data_matrix)==mutationTypesZou)){
    catalogueType <- "Zou"
  }else if(all(rownames(signature_data_matrix)==mutationTypesAlexandrov)){
    catalogueType <- "Alexandrov"
  }else{
    message("Unknown DNV channels (rownames) style, please use NN>NN rownames in either Zou or Alexandrov style")
    exit(1)
  }
  
  if(catalogueType=="Zou"){
    muttypeslength <- c(9,9,9,6,9,9,6,9,6,6)
    mypalette <- c("#e6194b","#3cb44b","#ffe119","#0082c8","#f58231","#911eb4","#46f0f0","#f032e6","#d2f53c","#fabebe")
    muttypes <- c("AA>NN","AC>NN","AG>NN","AT>NN","CA>NN","CC>NN","CG>NN","GA>NN","GC>NN","TA>NN")
  }else if(catalogueType=="Alexandrov"){
    muttypeslength <- c(9,6,9,6,9,6,6,9,9,9)
    mypalette <- c(rgb(164,205,224,maxColorValue = 255),
                   rgb(31,119,182,maxColorValue = 255),
                   rgb(176,222,139,maxColorValue = 255),
                   rgb(50,160,43,maxColorValue = 255),
                   rgb(252,152,152,maxColorValue = 255),
                   rgb(227,33,29,maxColorValue = 255),
                   rgb(243,185,109,maxColorValue = 255),
                   rgb(250,125,0,maxColorValue = 255),
                   rgb(200,175,210,maxColorValue = 255),
                   rgb(105,60,155,maxColorValue = 255))
    muttypes <- c("AC>NN","AT>NN","CC>NN","CG>NN","CT>NN","GC>NN","TA>NN","TC>NN","TG>NN","TT>NN")
  }else{
    message("Unknown catalogue type.")
    exit(1)
  }
  
  rearr.colours <- c()
  for (i in 1:length(mypalette)) rearr.colours <- c(rearr.colours,rep(mypalette[i],muttypeslength[i]))
  
  nplotrows <- ncol(signature_data_matrix)
  if(!is.null(output_file)) {
    if(plottype=="jpg"){
      jpeg(output_file,width = 2*800,height = nplotrows*320,res = 220)
    }else if (plottype=="pdf"){
      pdf(output_file,width = 2*8,height = nplotrows*3.2,pointsize = 26)
    }
    par(mfrow = c(nplotrows, 2),oma=c(0,0,2,0))
  }
  for (pos in 1:ncol(signature_data_matrix)){
    ylimit <- c(0,max(signature_data_matrix[,pos],mean_matrix[,pos]+sd_matrix[,pos]))
    if(is.null(mar)){
      par(mar=c(2,3,2,2))
    }else{
      par(mar=mar)
    }
    title <- colnames(signature_data_matrix)[pos]
    if (plot_sum) title <- paste0(title," (",round(sum(signature_data_matrix[,pos]))," DNVs)")
    if (!is.null(add_to_titles)) title <- paste0(title,"\n",add_to_titles[pos])
    xlabels <- rep("",nrow(signature_data_matrix))
    xlabels2 <- sapply(rownames(signature_data_matrix),function(x){
      strsplit(x,split = ">")[[1]][2]
    })
    
    b <- barplot(signature_data_matrix[,pos],
                 main = title,
                 #names.arg = row.names(signature_data_matrix),
                 names.arg = xlabels,
                 col=rearr.colours,
                 beside = TRUE,
                 las=2,
                 cex.names = 1,border = NA,space = 0.2)
    par(xpd=TRUE)
    par(usr = c(0, 1, 0, 1))
    recttop <- -0.092
    rectbottom <- -0.21
    start1 <- 0.037
    endfinal <- 0.963
    gap <- (endfinal-start1)/nrow(signature_data_matrix)
    xpos2 <- start1 - gap/2 + 1:length(xlabels2)*gap
    text(x=xpos2,y = -0.04,label = xlabels2,srt=90,cex = 0.3)
    for (i in 1:length(mypalette)) {
      end1 <- start1+gap*muttypeslength[i]
      rect(start1, rectbottom, end1, recttop,col = mypalette[i],lwd = 0,border = NA)
      text(x =start1+(end1-start1)/2,y = -0.15,labels = muttypes[i],col = "black",font = 2,cex = 0.5)
      start1 <- end1
    }
    
    par(xpd=FALSE)
    
    barCenters <- barplot(mean_matrix[,pos],
                         main = title,
                         #names.arg = row.names(signature_data_matrix),
                         names.arg = xlabels,
                         col=rearr.colours,
                         beside = TRUE,
                         las=2,
                         cex.names = 1,border = NA,space = 0.2)
    segments(barCenters, mean_matrix[,pos], barCenters,
             mean_matrix[,pos] + sd_matrix[,pos], lwd = 1)
    par(xpd=TRUE)
    par(usr = c(0, 1, 0, 1))
    recttop <- -0.092
    rectbottom <- -0.21
    start1 <- 0.037
    endfinal <- 0.963
    gap <- (endfinal-start1)/nrow(signature_data_matrix)
    xpos2 <- start1 - gap/2 + 1:length(xlabels2)*gap
    text(x=xpos2,y = -0.04,label = xlabels2,srt=90,cex = 0.3)
    for (i in 1:length(mypalette)) {
      end1 <- start1+gap*muttypeslength[i]
      rect(start1, rectbottom, end1, recttop,col = mypalette[i],lwd = 0,border = NA)
      text(x =start1+(end1-start1)/2,y = -0.15,labels = muttypes[i],col = "black",font = 2,cex = 0.5)
      start1 <- end1
    }
    
    par(xpd=FALSE)   
    
  }
  title(main = overall_title,outer = TRUE,cex.main = 2)
  if(!is.null(output_file)) dev.off()
}

#' Convert DNV catalogues from Zou's to Alexandrov's style
#' 
#' Function to convert DNV signatures or catalogues from Zou's to Alexandrov's style. This will simply move and rename the channels.
#' 
#' @param dnvCatalogues DNV catalogues in Zou's style
#' @return DNV Catalogues in Alexandrov style
#' @export
convertToAlexandrovChannels <- function(dnvCatalogues){
  # Ludmil's channels
  mutationTypes <-    c("AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
                        "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
                        "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
                        "CG>AT","CG>GC","CG>GT","CG>TA","CG>TC","CG>TT",
                        "CT>AA","CT>AC","CT>AG","CT>GA","CT>GC","CT>GG","CT>TA","CT>TC","CT>TG",
                        "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
                        "TA>AT","TA>CG","TA>CT","TA>GC","TA>GG","TA>GT",
                        "TC>AA","TC>AG","TC>AT","TC>CA","TC>CG","TC>CT","TC>GA","TC>GG","TC>GT",
                        "TG>AA","TG>AC","TG>AT","TG>CA","TG>CC","TG>CT","TG>GA","TG>GC","TG>GT",
                        "TT>AA","TT>AC","TT>AG","TT>CA","TT>CC","TT>CG","TT>GA","TT>GC","TT>GG")
  
  oldmutationTypes <- c("AC>CA","AC>CG","AC>CT","AC>GA","AC>GG","AC>GT","AC>TA","AC>TG","AC>TT",
                        "AT>CA","AT>CC","AT>CG","AT>GA","AT>GC","AT>TA",
                        "CC>AA","CC>AG","CC>AT","CC>GA","CC>GG","CC>GT","CC>TA","CC>TG","CC>TT",
                        "CG>AT","CG>GC","CG>AC","CG>TA","CG>GA","CG>AA",
                        "AG>TT","AG>GT","AG>CT","AG>TC","AG>GC","AG>CC","AG>TA","AG>GA","AG>CA",
                        "GC>AA","GC>AG","GC>AT","GC>CA","GC>CG","GC>TA",
                        "TA>AT","TA>CG","TA>AG","TA>GC","TA>CC","TA>AC",
                        "GA>TT","GA>CT","GA>AT","GA>TG","GA>CG","GA>AG","GA>TC","GA>CC","GA>AC",
                        "CA>TT","CA>GT","CA>AT","CA>TG","CA>GG","CA>AG","CA>TC","CA>GC","CA>AC",
                        "AA>TT","AA>GT","AA>CT","AA>TG","AA>GG","AA>CG","AA>TC","AA>GC","AA>CC")
  newDNVcatalogues <- dnvCatalogues
  newDNVcatalogues[,] <- 0
  rownames(newDNVcatalogues) <- mutationTypes
  for (i in 1:length(mutationTypes)) newDNVcatalogues[mutationTypes[i],] <- dnvCatalogues[oldmutationTypes[i],]
  return(newDNVcatalogues)
}




