#' combine documents in a dfm by a grouping variable
#' 
#' Combine documents in a \link{dfm} by a grouping variable, which can also be 
#' one of the \link{docvars} attached to the dfm. This is identical in 
#' functionality to using the \code{"groups"} argument in \code{\link{dfm}}.
#' @param x a \link{dfm}
#' @inheritParams groups
#' @param fill logical; if \code{TRUE} and \code{groups} is a factor, then use 
#'   all levels of the factor when forming the new "documents" of the grouped 
#'   dfm.  This will result in documents with zero feature counts for levels not
#'   observed.  Has no effect if the \code{groups} variable(s) are not factors.
#' @return \code{dfm_group} returns a \link{dfm} whose documents are equal to 
#'   the unique group combinations, and whose cell values are the sums of the 
#'   previous values summed by group.  This currently erases any docvars in the 
#'   dfm.
#'   
#'   Setting the \code{fill = TRUE} offers a way to "pad" a dfm with document
#'   groups that may not have been observed, but for which an empty document is
#'   needed, for various reasons.  If \code{groups} is a factor of dates, for
#'   instance, then using \code{fill = TRUE} ensures that the new documents will
#'   consist of one row of the dfm per date, regardless of whether any documents
#'   previously existed with that date.
#' @export
#' @examples
#' mycorpus <- corpus(c("a a b", "a b c c", "a c d d", "a c c d"), 
#'                    docvars = data.frame(grp = c("grp1", "grp1", "grp2", "grp2")))
#' mydfm <- dfm(mycorpus)
#' dfm_group(mydfm, groups = "grp")
#' dfm_group(mydfm, groups = c(1, 1, 2, 2))
#' 
#' # equivalent
#' dfm(mydfm, groups = "grp")
#' dfm(mydfm, groups = c(1, 1, 2, 2))
dfm_group <- function(x, groups = NULL, fill = FALSE) {
    UseMethod("dfm_group")
}

#' @noRd
#' @export
dfm_group.dfm <- function(x, groups = NULL, fill = FALSE) {
    
    x <- as.dfm(x)
    if (is.character(groups) & all(groups %in% names(docvars(x)))) {
        groups <- interaction(docvars(x)[, groups], drop = FALSE)
    }
    if (ndoc(x) != length(groups)) {
        stop("groups must name docvars or provide data matching the documents in x\n")
    }
    if(!fill || !is.factor(groups))
        groups <- factor(groups, levels = sort(unique(groups)))
    x <- group_dfm(x, documents = groups, fill = fill)
    if (!is.null(groups))
        x <- x[as.character(levels(groups)),]
    x@docvars <- data.frame(row.names = docnames(x))
    return(x)
}



#
# internal code to perform dfm compression and grouping
# on features and/or documents
group_dfm <- function(x, features = NULL, documents = NULL, fill = FALSE) {
    
    if (is.null(features) && is.null(documents)) {
        return(x)
    }
    
    temp <- as(x, "dgTMatrix")
    
    if (is.null(features)) {
        features_name <- temp@Dimnames[[2]]
        j_new <- temp@j + 1
    } else {
        features_unique <- unique(features)
        features_index <- match(features, features_unique)
        j_new <- features_index[temp@j + 1]
        
        #print(as.character(levels(features)))
        #print(features_name)
        if(!is.factor(features))
            features <- factor(features, levels = features_unique)
        features_name <- as.character(features_unique)
        if (fill && !identical(levels(features), features_unique)) {
            features_name <- c(features_name, setdiff(as.character(levels(features)), 
                                                      as.character(features_unique)))
        }
    }
    if (is.null(documents)) {
        documents_name <- temp@Dimnames[[1]]
        i_new <- temp@i + 1
    } else {
        documents_unique <- unique(documents)
        documents_index <- match(documents, documents_unique)
        i_new <- documents_index[temp@i + 1]
        
        #print(as.character(levels(documents)))
        #print(documents_name)
        if(!is.factor(documents))
            documents <- factor(documents, levels = documents_unique)
        documents_name <- as.character(documents_unique)
        if (fill && !identical(levels(documents), documents_unique)) {
            documents_name <- c(documents_name, setdiff(as.character(levels(documents)), 
                                                        as.character(documents_unique)))
        }
    }
    
    x_new <- temp@x
    dims <- c(length(documents_name), length(features_name))
    dimnames <- list(docs = documents_name, features = features_name)
    
    result <- new("dfm", 
                  sparseMatrix(i = i_new, j = j_new, x = x_new, dims = dims, dimnames = dimnames),
                  settings = x@settings,
                  weightTf = x@weightTf,
                  weightDf = x@weightDf,
                  smooth = x@smooth,
                  ngrams = x@ngrams,
                  skip = x@skip,
                  concatenator = x@concatenator)
    
    if (is.null(documents)) {
        docvars(result) <- docvars(x)
    } else {
        docvars(result) <- data.frame(row.names = documents_name)
    }
    return(result)
}
