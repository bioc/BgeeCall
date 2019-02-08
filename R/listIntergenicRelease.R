#' @title List Bgee intergenic releases available to use with the BgeeCall package
#'
#' @description Returns information on available Bgee intergenic releases, 
#' the access URL for FTP, and the date of release
#'
#' @param release A character specifying a targeted release number (e.g., "14"). 
#' If not specified, all available releases are shown.
#'
#' @return A data frame with information on Bgee intergenic releases available to 
#' use with the BgeeCall package.
#'
#' @examples{
#'  list_intergenic_release()
#' }
#'
#' @author Julien Roux, Julien Wollbrett
#' @export

# Function displaying the user a data frame describing all intergenic releases 
# available for the BgeeCall package
list_intergenic_release <- function(release=NULL){
    cat("Downloading release information of Bgee intergenic regions...\n")
    allReleases <- .getIntergenicRelease(removeFile = TRUE)
    if (length(release) == 1){
        if (sum(allReleases$release == 1)) {
            cat(paste0("Only displaying information from targeted release ",
                       release, "\n"))
            allReleases <- allReleases[allReleases$release == release, ]
        } else {
            stop("ERROR: The specified release number is invalid or is not available for 
           BgeeCall.")
        }
    }
    ## Only return the columns of interest to the user
    return(allReleases[, c("release","releaseDate", "FTPURL", 
                           "referenceIntergenicFastaURL", "minimumVersionBgeeCall", 
                           "description", "messageToUsers")])
}

# Function returning a data frame describing all intergenic releases available 
# for the BgeeCall package
.getIntergenicRelease <- function(removeFile=TRUE){
    ## query FTP to get file describing all releases
    releaseUrl <- 'ftp://ftp.bgee.org/intergenic/intergenic_release.tsv'
    success <- try(download.file(url = releaseUrl, quiet = TRUE,
                                 destfile = file.path(getwd(), 'release.tsv.tmp')))
    if (success == 0 & file.exists(file.path(getwd(), 'release.tsv.tmp'))) {
        file.rename(from=file.path(getwd(), 'release.tsv.tmp'),
                    to=file.path(getwd(), 'release.tsv'))
        allReleases <- read.table(file = "release.tsv", header = TRUE, sep = "\t")
        if (removeFile == TRUE){
            file.remove(file.path(getwd(), 'release.tsv'))
        }
    } else {
        file.remove(file.path(getwd(), 'release.tsv.tmp'))
        stop("ERROR: File describing intergenic releases could not be downloaded 
         from FTP.")
    }
    ## Keep intergenic releases available with the current version of the package
    allAvailableReleases <- 
        allReleases[vapply(as.character(allReleases$minimumVersionBgeeCall), 
                           compareVersion, numeric(1), 
                           as.character(packageVersion("BgeeCall"))) <= 0,]
    return(allAvailableReleases)
}