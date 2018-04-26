#TODO
#CHECK Packages:
# cranly
# pdftools
# ndtv
# networkD3
# threejs
# visNetwork
# animation

library(pdftools)
?pdftools
setwd('traversing_graphs_in_R/')
pdf_file <- 'useR! Abstracts/user2017.pdf'
info <- pdf_info(pdf_file)
text <- pdf_text(pdf_file)

library(tidyverse)

toc <- text[2:22]
pages <- text[22:length(text)]
removeFromToc <- c(
  'I Talks\n', #23
  'II Lightning Talks\n', #162
  'III Posters\n', #226,
  'CONTENTS([^\n]+CONTENTS)?\n',
  '\\b\\s+\\d+\\n$'
)

toc <- toc %>%
  str_replace_all(regex(str_c(removeFromToc, collapse = '|'), 
                        ignore_case = T), 
                  replace = '')  %>%
  str_split('\n')  %>%
  do.call(c, .)

toc_list <- list()

toc_count = 0

for(i in seq_along(toc)){
  myLine = toc[i]
  if(str_detect(myLine, '^\\S')){
    toc_count = toc_count + 1;
    toc_list[[toc_count]] = c(myLine)
  } else {
    toc_list[[toc_count]][length(toc_list[[toc_count]]) + 1] = myLine
  }
}

toc_title_author <- lapply(toc_list, function(x){
  temp = x %>% str_c(collapse = '\n')
  pageNumber = str_extract(temp, '\\s+\\d+\n') 
  temp = str_split(temp, pageNumber)
  pageNumber = str_trim(pageNumber) %>%
    as.numeric()
  temp = temp[[1]] %>%
    str_replace_all('\\-\\n\\s+', '') %>%
    str_replace_all('\\n\\s+', ' ') %>%
    str_trim() 
  title = temp[1]
  author = temp[2] %>%
    str_split('\\,(\\s*and\\b)?|\\band\\b') %>%
    .[[1]] %>%
    str_trim()
  
  tibble(
    title = title,
    author = author,
    pageNumber = pageNumber
  ) 
}) %>%
  bind_rows() %>%
  filter(!is.na(pageNumber)) %>%
  mutate(type = sapply(pageNumber,function(x){
    if(x < 162){
      'Talks'
    } else if(x < 226){
      'Lightning Talks'
    } else {
      'Poster'
    }
  }))

toc_title_author

pages %>% .[str_extract(., '\\d+\\n$') %>% is.na]
