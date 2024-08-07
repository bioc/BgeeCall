#' @title Generate transcript to gene mapping for intergenic
#'
#' @description Generate transcript to gene mapping for intergenic regions as 
#' used by tximport. Gene and transcript columns are identical.
#'
#' @param myBgeeMetadata A Reference Class BgeeMetadata object.
#' @param myUserMetadata A Reference Class UserMetadata object.
#'
#' @author Julien Wollbrett
#'
#' @return transcript to gene mapping for intergenic regions
#'
#' @noMd
#' @noRd
#' 
#' @examples { 
#' user <- new('UserMetadata', species_id = '6239')
#' bgee <- new('BgeeMetadata', intergenic_release = '0.1')
#' intergenic_tx2gene(bgee, user)
#' }
intergenic_tx2gene <- function(myBgeeMetadata, myUserMetadata) {
    # retrieve intergenic IDs
    all_transcripts <- get_intergenic_ids(myBgeeMetadata, myUserMetadata)
    # Create a second column idantical to the first
    # one.  Then each intergenic region will be
    # consider as a gene (of the same name) for
    # tximport
    all_transcripts[, 2] <- all_transcripts[, 1]
    names(all_transcripts) <- c("TXNAME", "GENEID")
    return(all_transcripts)
}


#' @title Create TxDb annotation
#'
#' @description Create TxDb annotation from gtf or gff3 annotations
#'
#' @param myUserMetadata A Reference Class UserMetadata object.
#'
#' @author Julien Wollbrett
#'
#' @return TxDb annotation
#'
#' @import GenomicFeatures
#' @import txdbmaker
#'
#' @noMd
#' @noRd
#'
create_TxDb <- function(myUserMetadata) {
    # create txdb from GRanges Object
    # use the suppressWarnings function in order not to print useless warnings like :
    # The "phase" metadata column contains non-NA values for features of type stop_codon. This information was ignored.
    txdb <- suppressWarnings(makeTxDbFromGRanges(myUserMetadata@annotation_object, 
        taxonomyId = as.numeric(myUserMetadata@species_id)))
    return(txdb)
}


#' @title Create transcript to gene mapping file
#'
#' @description Create transcript to gene mapping file as used by tximport. 
#' The file contains both genic and intergenic regions.
#'
#' @param myAbundanceMetadata A descendant object of the Class 
#' myAbundanceMetadata.
#' @param myBgeeMetadata A Reference Class BgeeMetadata object.
#' @param myUserMetadata A Reference Class UserMetadata object.
#'
#' @author Julien Wollbrett
#'
#' @noMd
#' @noRd
#' 
#' @return path to the tx2gene file
#'
create_tx2gene <- function(myAbundanceMetadata, myBgeeMetadata, 
    myUserMetadata) {
    # create tx2gene from annotations
    annotation_path <- get_annotation_path(myBgeeMetadata, 
        myUserMetadata)
    tx2gene_file <- myAbundanceMetadata@tx2gene_file
    if (myAbundanceMetadata@ignoreTxVersion) {
        tx2gene_file <- myAbundanceMetadata@tx2gene_file_without_version
    }
    tx2gene_path <- file.path(annotation_path, tx2gene_file)
    if (!file.exists(tx2gene_path)) {
        if(isTRUE(myUserMetadata@verbose)) {
            message("Generate file ", tx2gene_file, ".\n")
        }
        if (!dir.exists(annotation_path)) {
            dir.create(annotation_path, recursive = TRUE)
        }
        txdb <- create_TxDb(myUserMetadata = myUserMetadata)
        k <- biomaRt::keys(txdb, keytype = "TXNAME")
        # Used suppressMessages in order not to print meesages like :
        # 'select()' returned 1:1 mapping between keys and columns
        tx2gene <- suppressMessages(as.data.frame(biomaRt::select(txdb, 
            k, "GENEID", "TXNAME")))
        intergenic_tx2gene <- intergenic_tx2gene(myBgeeMetadata = myBgeeMetadata, 
            myUserMetadata = myUserMetadata)
        
        # Remove the transcript version that can be present
        # in transcript id of gtf files
        if (myAbundanceMetadata@ignoreTxVersion) {
            if(isTRUE(myUserMetadata@verbose)) {
                message("remove transcript version info in ", 
                    tx2gene_file, " file.\n")
            }
            tx2gene$TXNAME <- gsub(pattern = "\\..*", 
                "", tx2gene$TXNAME)
        }
        tx2gene <- rbind(tx2gene, intergenic_tx2gene)
        
        write.table(x = tx2gene, file = tx2gene_path, 
            sep = "\t", row.names = FALSE, quote = FALSE)
    }
    return(tx2gene_path)
}

#' @title Run tximport
#'
#' @description Run tximport. Will summarize abundance estimation from transcript 
#' level to gene level if `myAbundanceMetadata@txout == FALSE`. 
#' Otherwise keep abundance estimation at transcript level.
#'
#' @param myAbundanceMetadata A descendant object of the Class 
#' myAbundanceMetadata.
#' @param myBgeeMetadata A Reference Class BgeeMetadata object.
#' @param myUserMetadata A Reference Class UserMetadata object.
#' @param abundanceFile  (Optional) Path to the abundance file. NULL by default.
#' If not NULL, the file located at `abundanceFile` will be used to run tximport.
#' Otherwise (Default) the path to the abundance file is deduced fom attributes of
#' classes `BgeeMetadata`, `UserMetadata` and `AbundanceMetadata`
#' 
#' @author Julien Wollbrett
#'
#' @import rhdf5
#' @import tximport
#'
#' @export
#' 
#' @examples {
#' user <- new("UserMetadata", working_path = system.file("extdata", 
#'     package = "BgeeCall"), species_id = "6239", 
#'   rnaseq_lib_path = system.file("extdata", 
#'     "SRX099901_subset", package = "BgeeCall"), 
#'   annotation_name = "WBcel235_84", simple_arborescence = TRUE)
#' abundance_file <- system.file('extdata', 'abundance.tsv', package = 'BgeeCall')
#' tx_import <- run_tximport(myUserMetadata = user, 
#' abundanceFile = abundance_file)
#' }
#' 
#' @return a tximport object
#'
run_tximport <- function(myAbundanceMetadata = new("KallistoMetadata"), 
    myBgeeMetadata = new("BgeeMetadata"), 
    myUserMetadata, abundanceFile = "") {
    tx2gene_path <- create_tx2gene(myAbundanceMetadata = myAbundanceMetadata, 
        myBgeeMetadata = myBgeeMetadata, myUserMetadata = myUserMetadata)
    tx2gene <- read.table(tx2gene_path, header = TRUE, 
        sep = "\t")
    
    abundance_file <- abundanceFile
    if (nchar(abundance_file) == 0) {
        abundance_file <- get_abundance_file_path(myAbundanceMetadata, 
            myBgeeMetadata, myUserMetadata)
    }
    if (!file.exists(abundance_file)) {
        stop(paste0("can not generate presence/absence calls. 
Abundance file is missing : ", 
            abundance_file, "."))
    }
    # fix bug when ignoreTxVersion is used AND contig/chromosome name contains a dot 
    # ignoreTxVersion option of tximport allows to remove version of transcripts. Name of intergenic regions was created using the approach
    # CONTIGNAME_START_STOP. However, if the contig name contains a "." then the ignoreTxVersion option remove everything after the "."
    # e.g. KB708127.1_324_4365 => KB708127
    # In order to solve this bug the name of intergenic regions is modified before tximport step. This modification is done only if ignoreTxVersion option is set to TRUE.
    if(myAbundanceMetadata@ignoreTxVersion) {
        if(isTRUE(myUserMetadata@verbose)) {
            message("As ignoreTxVersion==TRUE first need to verify that intergenic names does not contain any dot")
        }
        #create mapping data.frame in order to be able to change back TXNAME after tximport
        mapping_modify_intergenic <- tx2gene[as.character(tx2gene$TXNAME)==as.character(tx2gene$GENEID),]
        colnames(mapping_modify_intergenic) <- c(myAbundanceMetadata@transcript_id_header, "GENEID")
        mapping_modify_intergenic$modified <- as.character(gsub('\\.', '_', mapping_modify_intergenic[,1]))
        # update tx2gene
        tx2gene$TXNAME <- gsub('\\.', '_', tx2gene$TXNAME)
        # create temporary abundance file with modified name for intergenic regions
        temp_abundance <- read.table(file = abundance_file, header = TRUE, sep = "\t")
        #transform first column as character column
        temp_abundance[,1] <- as.character(temp_abundance[,1])
        is_intergenic <- with(temp_abundance, match(target_id, mapping_modify_intergenic[,1]))
        for (i in seq(is_intergenic)) {
            if(!is.na(is_intergenic[i])) {
                #message(mapping_modify_intergenic$modified[is_intergenic[i]])
                temp_abundance[i,1] <- as.character(mapping_modify_intergenic$modified[is_intergenic[i]])
            }
        }
        temp_abundance_file <- file.path(get_tool_output_path(myAbundanceMetadata, myBgeeMetadata,
                                                              myUserMetadata), "temp_abundance.tsv")
        write.table(x = temp_abundance, file = temp_abundance_file, quote = FALSE, sep = "\t", 
                    row.names = FALSE, col.names = TRUE)
        abundance_file <- temp_abundance_file
    }
    
    if(isTRUE(myUserMetadata@verbose)) {
        txi <- tximport(abundance_file, type = myAbundanceMetadata@tool_name, 
            tx2gene = tx2gene, txOut = myAbundanceMetadata@txOut, 
            ignoreTxVersion = myAbundanceMetadata@ignoreTxVersion)
    } else {
        txi <- suppressMessages(tximport(abundance_file, type = myAbundanceMetadata@tool_name, 
            tx2gene = tx2gene, txOut = myAbundanceMetadata@txOut, 
            ignoreTxVersion = myAbundanceMetadata@ignoreTxVersion))
    }
    # If ignoreTxVersion==TRUE temp abundance file was created. Now need to delete it
    if(myAbundanceMetadata@ignoreTxVersion) {
        file.remove(temp_abundance_file)
    }
    return(txi)
}

abundance_without_intergenic <- function(myAbundanceMetadata, 
    myBgeeMetadata, myUserMetadata) {
    file_without_intergenic_name <- "abundance_without_intergenic.tsv"
    
    #
    # remove intergenic from tx2gene
    tx2gene_path <- create_tx2gene(myAbundanceMetadata = myAbundanceMetadata, 
        myBgeeMetadata = myBgeeMetadata, myUserMetadata = myUserMetadata)
    intergenic_ids <- get_intergenic_ids(myBgeeMetadata, myUserMetadata)
    tx2gene <- read.table(tx2gene_path, header = TRUE, sep = "\t")
    
    tx2gene_without_intergenic <- subset(tx2gene, !(tx2gene$TXNAME %in% 
        intergenic_ids$intergenic_ids))
    
    # remove intergenic from abundance file
    output_path <- get_tool_output_path(myAbundanceMetadata, 
        myBgeeMetadata, myUserMetadata)
    abundance_file <- get_abundance_file_path(myAbundanceMetadata, 
        myBgeeMetadata, myUserMetadata)
    abundance <- read.table(abundance_file, header = TRUE, 
        sep = "\t")
    
    abundance_without_intergenic <- 
        abundance[which(abundance[[myAbundanceMetadata@transcript_id_header]] %in% 
        tx2gene_without_intergenic$TXNAME), ]
    
    # calculate corrected TPM value
    abundance_without_intergenic[myAbundanceMetadata@abundance_header] <- 
        countToTpm(abundance_without_intergenic[[myAbundanceMetadata@count_header]], 
        abundance_without_intergenic[[myAbundanceMetadata@eff_length_header]])
    
    temp_abundance_file_without_intergenic <- file.path(output_path, 
        file_without_intergenic_name)
    write.table(abundance_without_intergenic, temp_abundance_file_without_intergenic, 
        sep = "\t", row.names = FALSE)

    if(isTRUE(myUserMetadata@verbose)) {
        txi_without_intergenic <- tximport(temp_abundance_file_without_intergenic, 
            type = myAbundanceMetadata@tool_name, tx2gene = tx2gene_without_intergenic, 
            txOut = myAbundanceMetadata@txOut, ignoreTxVersion = myAbundanceMetadata@ignoreTxVersion)
    } else {
        txi_without_intergenic <- suppressMessages(tximport(temp_abundance_file_without_intergenic, 
            type = myAbundanceMetadata@tool_name, tx2gene = tx2gene_without_intergenic, 
            txOut = myAbundanceMetadata@txOut, ignoreTxVersion = myAbundanceMetadata@ignoreTxVersion))
    }
    file.remove(temp_abundance_file_without_intergenic)
    return(txi_without_intergenic)
}
