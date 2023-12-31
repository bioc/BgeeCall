#' @title List reference intergenic releases usable with the BgeeCall package
#'
#' @description Returns information on available Bgee intergenic releases, 
#' the access URL for FTP, and the date of release
#'
#' @param release A character specifying a targeted release number (e.g., '0.1'). 
#' If not specified, all available releases are shown.
#'
#' @return A data frame with information on Bgee intergenic releases available to 
#' use with the BgeeCall package.
#'
#' @examples{
#'  list_intergenic_release()
#' }
#'
#' @author Julien Wollbrett
#' @export

# Function displaying the user a data frame
# describing all intergenic releases available for
# the BgeeCall package
list_intergenic_release <- function(release = NULL) {
    message("Downloading release information of reference intergenic sequences...\n")
    allReleases <- listIntergenicReleases(removeFile = TRUE)
    if (length(release) == 1) {
        if (sum(allReleases$release == 1)) {
            message("Only displaying information from targeted release ", 
                release, "\n")
            allReleases <- allReleases[allReleases$release == 
                release, ]
        } else {
            stop("The specified release is invalid or is not available for 
            this version of BgeeCall.")
        }
    }
    ## Only return the columns of interest to the user
    return(allReleases[, c("release", "releaseDate", 
        "FTPURL", "referenceIntergenicFastaURL", "minimumVersionBgeeCall", 
        "description", "messageToUsers")])
}

# Function returning a data frame describing all
# intergenic releases available for the BgeeCall
# package
listIntergenicReleases <- function(removeFile = TRUE) {
    ## query FTP to get file describing all releases
    releaseUrl <- "https://bgee.org/ftp/intergenic/intergenic_release.tsv"
    success <- try(download.file(url = releaseUrl, 
        quiet = TRUE, destfile = file.path(getwd(), 
            "release.tsv.tmp")), silent = TRUE)
    if (success != 0) {
        if (file.exists(file.path(getwd(), "release.tsv"))) {
            warning("BgeeCall could not download intergenic releases 
information but a release information file was found locally. This release 
file will be used, but be warned that it may not be up to date!")
        } else {
            stop("File describing intergenic releases could not be downloaded 
from FTP.")
        }
    } else {
        file.rename(from = file.path(getwd(), "release.tsv.tmp"), 
            to = file.path(getwd(), "release.tsv"))
    }
    allReleases <- read.table(file = "release.tsv", 
        header = TRUE, sep = "\t")
    if (removeFile) {
        file.remove(file.path(getwd(), "release.tsv"))
    }
    allAvailableReleases <- allReleases[vapply(as.character(allReleases$minimumVersionBgeeCall), 
        compareVersion, numeric(1), as.character(packageVersion("BgeeCall"))) <= 0, ]
    return(allAvailableReleases)
}

