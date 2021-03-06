#' calculate keyness statistics
#' 
#' Calculate "keyness", a score for features that occur differentially across 
#' different categories.  Here, the categories are defined by reference to a
#' "target" document index in the \link{dfm}, with the reference group
#' consisting of all other documents.
#' @param x a \link{dfm} containing the features to be examined for keyness
#' @param target the document index (numeric, character or logical) identifying 
#'   the document forming the "target" for computing keyness; all other 
#'   documents' feature frequencies will be combined for use as a reference
#' @param measure (signed) association measure to be used for computing keyness.
#'   Currently available: \code{"chi2"}; \code{"exact"} (Fisher's exact test); 
#'   \code{"lr"} for the likelihood ratio; \code{"pmi"} for pointwise mutual 
#'   information.
#' @param sort logical; if \code{TRUE} sort features scored in descending order 
#'   of the measure, otherwise leave in original feature order
#' @param correction if \code{"default"}, Yates correction is applied to 
#'   \code{"chi2"}; William's correction is applied to \code{"lr"}; and no 
#'   correction is applied for the \code{"exact"} and \code{"pmi"} measures. 
#'   Specifying a value other than the default can be used to override the 
#'   defaults, for instance to apply the Williams correction to the chi2 
#'   measure.  Specifying a correction for the \code{"exact"} and \code{"pmi"} 
#'   measures has no effect and produces a warning.
#' @references Bondi, Marina, and Mike Scott, eds. 2010.  \emph{Keyness in 
#'   Texts}. Amsterdam, Philadelphia: John Benjamins, 2010.
#'   
#'   Stubbs, Michael. 2010.  "Three Concepts of Keywords". In \emph{Keyness in 
#'   Texts}, Marina Bondi and Mike Scott, eds. pp21–42. Amsterdam, Philadelphia:
#'   John Benjamins.
#'   
#'   Scott, M. & Tribble, C. 2006.  \emph{Textual Patterns: keyword and corpus 
#'   analysis in language education}.  Amsterdam: Benjamins, p. 55.
#'   
#'   Dunning, Ted. 1993. "Accurate Methods for the Statistics of Surprise and 
#'   Coincidence", \emph{Computational Linguistics}, Vol 19, No. 1, pp. 61-74.
#' @return a data.frame of computed statistics and associated p-values, where 
#'   the features scored name each row, and the number of occurrences for both 
#'   the target and reference groups. For \code{measure = "chi2"} this is the 
#'   chi-squared value, signed positively if the observed value in the target 
#'   exceeds its expected value; for \code{measure = "exact"} this is the 
#'   estimate of the odds ratio; for \code{measure = "lr"} this is the 
#'   likelihood ratio \eqn{G2} statistic; for \code{"pmi"} this is the pointwise
#'   mutual information statistics.
#' @export
#' @keywords textstat
#' @importFrom stats chisq.test
#' @examples
#' # compare pre- v. post-war terms using grouping
#' period <- ifelse(docvars(data_corpus_inaugural, "Year") < 1945, "pre-war", "post-war")
#' mydfm <- dfm(data_corpus_inaugural, groups = period)
#' head(mydfm) # make sure 'post-war' is in the first row
#' head(result <- textstat_keyness(mydfm), 10)
#' tail(result, 10)
#' 
#' # compare pre- v. post-war terms using logical vector
#' mydfm2 <- dfm(data_corpus_inaugural)
#' textstat_keyness(mydfm2, docvars(data_corpus_inaugural, "Year") >= 1945)
#' 
#' # compare Trump 2017 to other post-war preseidents
#' pwdfm <- dfm(corpus_subset(data_corpus_inaugural, period == "post-war"))
#' head(textstat_keyness(pwdfm, target = "2017-Trump"), 10)
#' # using the likelihood ratio method
#' head(textstat_keyness(dfm_smooth(pwdfm), measure = "lr", target = "2017-Trump"), 10)
textstat_keyness <- function(x, target = 1L, measure = c("chi2", "exact", "lr", "pmi"), sort = TRUE, 
                             correction = c("default", "yates", "williams", "none")) {
    UseMethod("textstat_keyness")
}

#' @noRd
#' @export
textstat_keyness.dfm <- function(x, target = 1L, measure = c("chi2", "exact", "lr", "pmi"), 
                                 sort = TRUE, correction = c("default", "yates", "williams", "none")) {
    
    
    x <- as.dfm(x)
    measure <- match.arg(measure)
    correction <- match.arg(correction)
    # error checking
    if (ndoc(x) < 2 )
        stop("x must have at least two documents")
    if (is.character(target) && !(target %in% docnames(x)))
        stop("target not found in docnames(x)")
    if (is.numeric(target) && (target < 1 | target > ndoc(x)))
        stop("target index outside range of documents")
    if (is.logical(target) && length(target) != ndoc(x))
        stop("target must be the same length as the number of documents")
    if (is.logical(target))
        target <- which(target)
    
    # get the target and reference documents by concatenating all non-target docs
    grouping <- rep(2, ndoc(x))
    names(grouping) <- docnames(x)
    grouping[target] <- 1
    rownames(x) <- grouping
    x <- dfm_compress(x, margin = 'documents')
    x <- x[order(docnames(x)), ]
    
    if (measure == "chi2") {
        keywords <- keyness_chi2_dt(x, correction)
    } else if (measure == "lr") {
        keywords <- keyness_lr(x, correction)
    } else if (measure == "exact") {
        if (!correction %in% c("default", "none"))
            warning("correction is always none for measure exact")
        keywords <- keyness_exact(x)
    } else if (measure == "pmi") {
        if (!correction %in% c("default", "none"))
            warning("correction is always none for measure pmi")
        keywords <- keyness_pmi(x)
    } else {
        stop(measure, " not yet implemented for textstat_keyness")
    }
    
    if (sort)
        keywords <- keywords[order(keywords[, 1], decreasing = TRUE), ]
    
    names(keywords)[which(names(keywords) == "target")] <- "n_target"
    names(keywords)[which(names(keywords) == "reference")] <- "n_reference"
    
    doc_names <- grouping[order(grouping)]
    attr(keywords, "documents") <- names(doc_names)
    
    return(keywords)
}


#' compute keyness (internal functions)
#' 
#' Internal function used in textstat_keyness.  Computes \eqn{chi^2} with Yates'
#' continuity correction for 2x2 tables.
#' @name keyness
#' @param x a \link{dfm} object
#' @details \code{keyness_chi2_dt} uses vectorized computation from data.table
#' objects.
#' @return a data.frame of chi2 and p-values with rows named for each feature
#' @examples
#' mydfm <- dfm(c(d1 = "a a a b b c c c c c c d e f g h h",
#'                d2 = "a a b c c d d d d e f h"))
#' quanteda:::keyness_chi2_dt(mydfm)
#' @keywords textstat internal
#' @import data.table
#' @importFrom stats dchisq
#' @references
#'   \url{https://en.wikipedia.org/wiki/Yates's_correction_for_continuity}
#'   
#'   
keyness_chi2_dt <- function(x, correction = c("default", "yates", "williams", "none")) {
    
    correction <- match.arg(correction)
    a <- b <- c <- d <- N <- E <- chi2 <- p <- cor_app <- q <- NULL 
    if (ndoc(x) > 2)
        stop("x can only have 2 rows")
    dt <- data.table(feature = featnames(x),
                     a = as.numeric(x[1, ]),
                     b = as.numeric(x[2, ]))
    dt[, c("c", "d") := list(sum(x[1, ]) - a, sum(x[2, ]) - b)]
    dt[, N := (a+b+c+d)]
    dt[, E := (a+b)*(a+c) / N]
    
    if (correction == "default" | correction == "yates"){
        dt[, cor_app := (((a+b)*(a+c)/N < 5 | (a+b)*(b+d)/N < 5 | (a+c)*(c+d)/N < 5 | (c+d)*(b+d)/N < 5) 
                         & abs(a*d - b*c) >= N/2)]
        # the correction is usually only recommended if the smallest expected frequency is less than 5
        # the correction should not be applied if |ad − bc| is less than N/2.
        # compute using the direct formula - see link above (adds sign)
        dt[, chi2 := ifelse(cor_app, 
                            (N * (abs(a*d - b*c) - N * 0.5)^2) / ((a+b)*(c+d)*(a+c)*(b+d)) * ifelse(a > E, 1, -1), 
                            (N * abs(a*d - b*c)^2) / ((a+b)*(c+d)*(a+c)*(b+d)) * ifelse(a > E, 1, -1) )]
    } else if (correction == "williams"){
        # William's correction cannot be used if there are any zeros in the table
        # \url{http://influentialpoints.com/Training/g-likelihood_ratio_test.htm}
        dt[, q := ifelse(a * b * c * d == 0, 1, 1 + (N/(a + b) + N/(c + d) - 1) * (N/(a + c) + N/(b + d) - 1) / (6 * N) )]
        dt[, chi2 := (N * abs(a*d - b*c)^2) / ((a+b)*(c+d)*(a+c)*(b+d)) * ifelse(a > E, 1, -1) / q]
    } else {
        dt[, chi2 := (N * abs(a*d - b*c)^2) / ((a+b)*(c+d)*(a+c)*(b+d)) * ifelse(a > E, 1, -1)]
    }
    
    # compute p-values
    dt[, p := 1 - stats::pchisq(abs(chi2), 1)]
    
    result <- as.data.frame(dt[, list(chi2, p)])
    rownames(result) <- dt$feature
    result$target = as.vector(x[1,])
    result$reference = as.vector(x[2,])
    return(result)
}

#' @rdname keyness
#' @importFrom stats chisq.test
#' @details 
#' \code{keyness_chi2_stats} uses element-by-element application of
#' \link[stats]{chisq.test}.
#' @examples 
#' quanteda:::keyness_chi2_stats(mydfm)
keyness_chi2_stats <- function(x) {
    keyness <- function(t, f, sum_t, sum_f) {
        # @param t (scalar) frequency of target 
        # @param f (scalar) frequency of reference
        # @param sum_t total of all target words
        # @param sum_f total of all reference words
        tb <- as.table(rbind(c(t, f), c(sum_t - t, sum_f - f)))
        suppressWarnings(chi <- stats::chisq.test(tb))
        t_exp <- chi$expected[1,1]
        list(chi2 = unname(chi$statistic) * ifelse(t > t_exp, 1, -1),
             p = unname(chi$p.value))
    }
    sums <- rowSums(x)
    result <- as.data.frame(
        do.call(rbind, apply(x, 2, function(y) keyness(as.numeric(y[1]), 
                                                       as.numeric(y[2]), 
                                                       sums[1], sums[2])))
    )
    result$target = as.vector(x[1,])
    result$reference = as.vector(x[2,])
    return(result)
}


#' @rdname keyness
#' @details 
#' \code{keyness_exact} computes Fisher's exact using element-by-element 
#' application of \link[stats]{fisher.test}, returning the odds ratio.
#' @importFrom stats fisher.test
#' @examples
#' quanteda:::keyness_exact(mydfm)
keyness_exact <- function(x) {
    sums <- rowSums(x)
    result <- as.data.frame(
        do.call(rbind, 
                apply(x, 2, function(y) { 
                    et <- stats::fisher.test(matrix(c(as.numeric(y), as.numeric(sums - y)), nrow = 2))
                    data.frame(or = as.numeric(et$estimate), p = et$p.value)
                }))
    )
    result$target = as.vector(x[1,])
    result$reference = as.vector(x[2,])
    return(result)
}


#' @rdname keyness
#' @param correction implement the Yates correction for 2x2 tables
#' @details \code{keyness_lr} computes the \eqn{G^2} likelihood ratio statistic
#'   using vectorized computation
#' @examples
#' quanteda:::keyness_lr(mydfm)
#' @references
#' \url{http://influentialpoints.com/Training/g-likelihood_ratio_test.htm}
keyness_lr <- function(x, correction = c("default", "yates", "williams", "none")) {
    
    correction <- match.arg(correction)
    epsilon <- 0.000000001; # to offset zero cell counts
    a <- b <- c <- d <- N <- E11 <- G2 <- p <- cor_app <- correction_sign <- q <- NULL 
    if (ndoc(x) > 2)
        stop("x can only have 2 rows")
    dt <- data.table(feature = featnames(x),
                     a = as.numeric(x[1, ]),
                     b = as.numeric(x[2, ]))
    dt[, c("c", "d") := list(sum(x[1, ]) - a, sum(x[2, ]) - b)]
    dt[, N := (a + b + c + d)]
    dt[, E11 := (a+b)*(a+c) / N]
    
    
    if (correction == "default" | correction == "yates"){
        
        dt[, cor_app := (((a+b)*(a+c)/N < 5 | (a+b)*(b+d)/N < 5 | (a+c)*(c+d)/N < 5 | (c+d)*(b+d)/N < 5) 
                         & abs(a*d - b*c) > N/2)]
        # the correction is usually only recommended if the smallest expected frequency is less than 5
        # the correction should not be applied if |ad − bc| is less than N/2.
        # implement Yates continuity correction
        # If (ad-bc) is positive, subtract 0.5 from a and d and add 0.5 to b and c. 
        # If (ad-bc) is negative, add 0.5 to a and d and subtract 0.5 from b and c.
        dt[, correction_sign := a*d - b*c > 0]
        dt[, c("a", "d", "b", "c") := list(a + ifelse(cor_app, ifelse(correction_sign, -0.5, 0.5), 0),
                                           d + ifelse(cor_app, ifelse(correction_sign, -0.5, 0.5), 0),
                                           b + ifelse(cor_app, ifelse(correction_sign, 0.5, -0.5), 0),
                                           c + ifelse(cor_app, ifelse(correction_sign, 0.5, -0.5), 0))]
    }
    
    dt[, G2 := (2 * (a * log(a / E11 + epsilon) + 
                         b * log(b / ((a+b)*(b+d) / N) + epsilon) +
                         c * log(c / ((a+c)*(c+d) / N) + epsilon) +
                         d * log(d / ((b+d)*(c+d) / N) + epsilon))) *
           ifelse(a > E11, 1, -1)]
    
    if (correction == "williams"){
        # William's correction cannot be used if there are any zeros in the table
        # \url{http://influentialpoints.com/Training/g-likelihood_ratio_test.htm}
        dt[, q := ifelse(a * b * c * d == 0, 1, 1 + (N/(a + b) + N/(c + d) - 1) * (N/(a + c) + N/(b + d) - 1) / (6 * N) )]
        dt[, G2 := G2 / q]
    }
    
    # compute p-values
    dt[, p := 1 - stats::pchisq(abs(G2), 1)]
    
    result <- as.data.frame(dt[, list(G2, p)])
    rownames(result) <- dt$feature
    result$target = as.vector(x[1,])
    result$reference = as.vector(x[2,])
    return(result)
}

#' @rdname keyness
#' @details \code{keyness_pmi} computes the Pointwise Mutual Information statistic
#'   using vectorized computation
#' @examples
#' quanteda:::keyness_pmi(mydfm)
keyness_pmi <- function(x) {
    
    a <- b <- c <- d <- N <- E11 <- pmi <- p <-NULL 
    if (ndoc(x) > 2)
        stop("x can only have 2 rows")
    dt <- data.table(feature = featnames(x),
                     a = as.numeric(x[1, ]),
                     b = as.numeric(x[2, ]))
    dt[, c("c", "d") := list(sum(x[1, ]) - a, sum(x[2, ]) - b)]
    dt[, N := (a + b + c + d)]
    dt[, E11 := (a+b)*(a+c) / N]
    epsilon <- .000000001  # to offset zero cell counts
    dt[, pmi :=   log(a /E11 + epsilon)]
    
    #normalized pmi
    #dt[, pmi :=   log(a  / E11) * ifelse(a > E11, 1, -1)/(-log(a/N)) ]
    
    
    # compute p-values
    dt[, p := 1 - stats::pchisq(abs(pmi), 1)]
    
    result <- as.data.frame(dt[, list(pmi, p)])
    rownames(result) <- dt$feature
    result$target = as.vector(x[1,])
    result$reference = as.vector(x[2,])
    return(result)
}


