context("test spacyr methods")

test_that("test quanteda methods for spacy_parsed objects", {
    load("../data/data_spacy_parsed.RData")
    expect_equal(docnames(data_spacy_parsed), "text1")
    expect_equal(ndoc(data_spacy_parsed), 1)
    expect_equal(ntype(data_spacy_parsed), c(text1 = 7))
    expect_equal(ntoken(data_spacy_parsed), c(text1 = 7))
})

test_that("test as.tokens works for spacy_parsed objects", {
    load("../data/data_spacy_parsed.RData")
    expect_equal(
        as.tokens(data_spacy_parsed) %>% as.list(),
        list(text1 = c("And", "now", "for", "something", "completely", "different", "."))
    )
    expect_equal(
        as.tokens(data_spacy_parsed, include_pos = "pos") %>% as.list(),
        list(text1 = c("And/CCONJ", "now/ADV", "for/ADP", "something/NOUN", 
                       "completely/ADV", "different/ADJ", "./PUNCT"))
    )
    expect_equal(
        as.tokens(data_spacy_parsed, include_pos = "tag") %>% as.list(),
        list(text1 = c("And/CC", "now/RB", "for/IN", "something/NN", 
                       "completely/RB", "different/JJ", "./."))
    )
    expect_equal(
        as.tokens(data_spacy_parsed, use_lemma = TRUE) %>% as.list(),
        list(text1 = c("and", "now", "for", "something", "completely", "different", "."))
    )
})
