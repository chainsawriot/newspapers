import_nexis_uk_html <- function(file, paragraph_separator, language_date, raw_date){

    #Convert format
    cat('Reading', file, '\n')

    line <- readLines(file, warn = FALSE, encoding = "UTF-8")
    html <- paste0(fix_nexis_uk_html(line), collapse = "\n")

    #Load as DOM object
    dom <- htmlParse(html, encoding = "UTF-8")
    data <- data.frame()
    for(doc in getNodeSet(dom, '//doc')){
        attrs <- extract_nexis_uk_attrs(doc, paragraph_separator, language_date, raw_date)
        if (attrs$pub[1] == '' || is.na(attrs$pub[1]))
            warning('Failed to extract publication name in ', file, call. = FALSE)
        if (attrs$date[1] == '' || is.na(attrs$date[1]))
            warning('Failed to extract date in ', file, call. = FALSE)
        if (attrs$head[1] == '' || is.na(attrs$head[1]))
            warning('Failed to extract heading in ', file, call. = FALSE)
        if (attrs$body[1] == '' || is.na(attrs$body[1]))
            warning('Failed to extract body text in ', file, call. = FALSE)
        data <- rbind(data, as.data.frame(attrs, stringsAsFactors = FALSE))
    }
    colnames(data) <- c('pub', 'edition', 'date', 'byline', 'length', 'section', 'head', 'body')
    data$file <- basename(file)

    return(data)
}


extract_nexis_uk_attrs <- function(node, paragraph_separator, language_date, raw_date) {

    attrs <- list(pub = '', edition = '', date = '', byline = '', length = '', section = '', head = '', body = '')

    if (language_date == 'german') {
        regex <- paste0(c('([0-9]{1,2})',
                          '[. ]+(Januar|Februar|M\u00e4rz|Maerz|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember)',
                          '[ ]+([0-9]{4})',
                          '([ ]+(Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag))?',
                          '([, ]+(.+))?'), collapse = '')
    } else {
        regex <- paste0(c('(January|February|March|April|May|June|July|August|September|October|November|December)',
                          '[, ]+([0-9]{1,2})',
                          '[, ]+([0-9]{4})',
                          '([,; ]+(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday))?',
                          '([, ]+(.+))?'), collapse = '')
    }

    n_max <- 0;
    i <- 1
    #print(node)
    for(div in getNodeSet(node, './/div')){

        str <- xmlValue(div, './/text()')
        str <- clean_text(str)
        n <- stri_length(str);
        if (is.na(n)) next

        #cat('----------------\n')
        #cat(i, stri_trim(s), "\n")

        if (i == 2) {
            attrs$pub <- stri_trim(str)
        } else if (i == 3) {
            if (raw_date) {
                attrs$date <- stri_trim(str)
            } else {
                m <- stri_match_first_regex(str, regex)
                if (all(!is.na(m[1,2:4]))) {
                    date <- paste0(m[1,2:4], collapse = ' ')
                    if (language_date == 'german') {
                        datetime <- stri_datetime_parse(date, 'd MMMM Y', locale = 'de_DE')
                    } else {
                        datetime <- stri_datetime_parse(date, 'MMMM d Y', locale = 'en_EN')
                    }
                    attrs$date <- stri_datetime_format(datetime, 'yyyy-MM-dd')
                }
                if (!is.na(m[1,8])) {
                    attrs$edition <- stri_trim(m[1,8])
                }
            }
        } else if (i == 4) {
            attrs$head <- stri_trim(str)
        } else if (i >= 5) {
            if (stri_detect_regex(str, "^BYLINE: ")) {
                attrs$byline = stri_trim(stri_replace_first_regex(str, "^BYLINE: ", ''))
            } else if (stri_detect_regex(str, "^SECTION: ")) {
                attrs$section = stri_trim(stri_replace_first_regex(str, "^SECTION: ", ''));
            } else if (stri_detect_regex(str, "^LENGTH: ")) {
                attrs$length = stri_trim(stri_replace_all_regex(str, "[^0-9]", ''))
            } else if (!is.null(attrs$length) && n > n_max &&
                       !stri_detect_regex(str, "^(BYLINE|URL|LOAD-DATE|LANGUAGE|GRAPHIC|PUBLICATION-TYPE|JOURNAL-CODE): ")){
                ps <- getNodeSet(div, './/p')
                p <- sapply(ps, xmlValue)
                attrs$body <- stri_trim(paste0(p, collapse = paste0(' ', paragraph_separator, ' ')))
                n_max = n
            }
        }
        i <- i + 1
    }
    return(attrs)
}


fix_nexis_uk_html <- function(line){
    d <- 0
    for (i in seq_along(line)) {
        l <- line[i]
        if (stri_detect_fixed(l, '<DOC NUMBER=1>')) d <- d + 1
        l = stri_replace_all_fixed(l, '<!-- Hide XML section from browser', '');
        l = stri_replace_all_fixed(l, '<DOC NUMBER=1>', paste0('<DOC ID="doc_id_',  d,  '">', collapse = ''))
        l = stri_replace_all_fixed(l, '<DOCFULL> -->', '<DOCFULL>');
        l = stri_replace_all_fixed(l, '</DOC> -->', '</DOC>');
        l = stri_replace_all_fixed(l, '<BR>', '<BR> ');
        line[i] <- l
    }
    return(line)
}
