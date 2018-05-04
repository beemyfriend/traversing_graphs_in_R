##############
### 2015 
#############
text <- pdf_text('useR! Abstracts/useR2015.pdf')

toc <- pdf_toc('useR! Abstracts/useR2015.pdf')

title_info <- lapply(toc$children, function(x){
  talk_type = x$title
  lapply(x$children, function(y){
    sub_type = y$title
    lapply(y$children, function(z){
      tibble(title = z$title)
    }) %>%
      bind_rows() %>%
      mutate(sub_type = sub_type)
  }) %>%
    bind_rows() %>%
    mutate(talk_type = talk_type,
           pageNumber = map2((1:nrow(.)), talk_type, function(i, x){
             switch(x, 
                    "Invited speakers" = i + 18,
                    "Oral Presentation" = i + 25,
                    "Lightning Talks" = i + 151,
                    "Posters" = i + 166,
                    "Sponsor Session" = 244 + i)
             }) %>% unlist,
           pageBody = map2_chr(pageNumber, title, function(i, x){
             pBody <- text[i+1] %>% 
               str_replace('^[^\\n]+\\n', '') %>%
               str_replace('^Chair:[^\\n]+\\n', '')}),
           keywords = str_extract(pageBody %>% str_replace_all('\\n', ' '), '(?<=Keywords:).+$') %>%
             str_replace('\\- ', '') %>%
             str_replace('\\d\\d\\d? $', '')
           )
  }) %>%
  bind_rows

toc_authors <- text[4:18] %>%
  str_replace('^[^\\n]+\\n', '') %>%
  str_split('\\n') %>%
  unlist() %>% 
  str_replace_all('( \\.)+', ' ')

toc_authors <- map2(title_info$pageNumber, title_info$title, function(i, x){
  last_word <- str_replace_all(x, '[:punct:]', ' ') %>% str_split(' ') %>% unlist %>% .[length(.)] 
  toc_index <- (1:length(toc_authors))[str_detect(toc_authors, str_c(last_word, '\\s+', as.integer(i), '$'))]
  if(!identical(toc_index, integer(0))){
    toc_authors[toc_index + 1] %>% .[length(.)]
  } else {
    NA
  }
})

title_info <- title_info %>% mutate(authors = toc_authors) %>% unnest()
title_info[71,]$authors <- 'Marvin Steijaert, Vladimir Chupakhin, Hugo Ceulemans, Joerg Wegner'

abstract_book_2015 <- title_info %>%
  mutate(title_authors = authors %>%
           str_replace('‡|†', '') %>%
           str_split(',|\\band\\b|/|\\&|;')) %>%
  unnest() %>%
  mutate(title_authors = title_authors %>% str_trim %>% str_to_upper) %>%
  mutate(talk_keywords = keywords %>%
           str_replace_all('- ', '') %>%
           str_split(',') %>%
           lapply(., function(x){x %>% str_trim %>% str_to_upper %>% .[. != '']})) %>%
  unnest() %>%
  mutate(talk_title = title %>% stringi::stri_escape_unicode() %>% str_replace_all('\\\\u.{4}', '')) %>%
  mutate(talk_body = pageBody %>% str_replace_all('\\n', ' ') %>% stringi::stri_escape_unicode() %>% str_replace_all('\\\\u.{4}', ' '))


abstracts = abstract_book_2015 %>%
  select(talk_title, talk_body, talk_type) %>%
  distinct() %>%
  rename(name = talk_title,
         pageBody = talk_body,
         abstractType = talk_type) %>%
  mutate(nodeType = 'ABSTRACT') %>%
  group_by(name, nodeType, pageBody) %>%
  summarize(abstractType = str_c(abstractType, collapse = '; '))

author = abstract_book_2015 %>%
  select(title_authors) %>%
  distinct() %>%
  rename(name = title_authors) %>%
  mutate(nodeType = 'AUTHOR')

keywords = abstract_book_2015 %>%
  select(talk_keywords) %>%
  distinct() %>%
  rename(name = talk_keywords) %>%
  mutate(nodeType = 'KEYWORD')

node_list <- list(author, keywords, abstracts) %>% bind_rows %>% filter(name != '')


author_abstract = abstract_book_2015 %>%
  select(talk_title, title_authors) %>%
  distinct() %>%
  select(source = title_authors,
         target = talk_title) %>%
  filter(!is.na(source),
         !is.na(target)) %>%
  mutate(type = 'WROTE')

abstract_keyword = abstract_book_2015 %>%
  select(talk_title, talk_keywords) %>%
  distinct() %>% 
  rename(source = talk_title,
         target = talk_keywords) %>%
  filter(!is.na(source),
         !is.na(target)) %>%
  mutate(type = 'CONTAINS')

edge_list <- rbind(author_abstract, abstract_keyword) %>%
  filter(source != '', 
         target != '')


g2015 <- graph_from_data_frame(edge_list, T, node_list)
write_graph(g2015, 'data/g2015.graphml', 'graphml')


g2017 <- read_graph('data/g2017.graphml', 'graphml')
new_nodes <- V(g2016)[!name %in% names(V(g2017))] %>%
  as_data
new_edges <- E(g2016)
g2017 + new_nodes

setwd('traversing_graphs_in_R/')
library(igraph)
library(tidyverse)
g2017 <- read_graph('data/g2017.graphml', 'graphml')
g2016 <- read_graph('data/g2016.graphml', 'graphml')
g2015 <- read_graph('data/g2015.graphml', 'graphml')

node_list <- ls() %>%
  .[str_detect(., 'g20\\d\\d')] %>%
  lapply(function(x){
    get(x, envir = .GlobalEnv) %>%
      igraph::as_data_frame('vertices')
  }) %>%
  bind_rows() %>%
  select(-id) %>%
  distinct()

edge_list <- ls() %>%
  .[str_detect(., 'g20\\d\\d')] %>%
  lapply(function(x){
    get(x, envir = .GlobalEnv) %>%
      igraph::as_data_frame('edges')
  }) %>%
  bind_rows() %>%
  distinct()

g <- graph_from_data_frame(edge_list, T, node_list)

degree(g) %>%
  .[names(.) %in% V(g)[nodeType == 'AUTHOR']$name] %>% 
  sort(T) %>%
  .[. > 3]

text2013 <- pdftools::pdf_text('useR! Abstracts/useR2013.pdf')
toc2013 <- pdftools::pdf_toc('useR! Abstracts/useR2013.pdf')

abstracts2013 <- toc2013$children %>%
  lapply(function(x){
    title1 <- x$title
  
      x$children %>%
      lapply(function(y){
        title2 <- y$title

        y$children %>%
          lapply(function(z){
            tibble(
              title3 = z$title
            )
          }) %>%
          bind_rows() %>%
          mutate(title2 = title2)
      }) %>%
      bind_rows %>%
      mutate(title1 = title1)
  }) %>%
  bind_rows() %>%
  mutate(page = 6 + 1:nrow(.),
         page = ifelse(page >= 137, page + 1, page)) %>%
  rbind(
    tibble(
      title3 = "Asymmetric Volatility Transmission in Airline Related Companies in Stock Markets",
      title2 = 'Poster',
      title1 = "Regular Posters",
      page = 137
    ) 
  ) %>%
  mutate(
    title2 = ifelse(page >= 137, 'Poster', title2),
    abstractBody = text2013[page] %>%
      str_replace('^[^\\n]*\\n', ''),
    authors = map2(title3, abstractBody, function(x,y){
      final_word <- x %>%
        str_replace_all('[:punct:]', ' ') %>%
        str_trim() %>%
        str_split(' ') %>%
        unlist() %>%
        .[length(.)]
      
      temp <- y %>%
        str_split('\\n') %>%
        unlist() 
      
      (1:length(temp))[str_detect(temp, str_c(final_word, '.*$'))][1] %>%
        (function(x){
          if(!is.na(x)){
            r = ((x+1):(x+4))
            temp[r] %>% 
              str_trim() %>% 
              .[!str_detect(., '^\\?')] %>%
              {
                if(str_detect(.[1], '^\\d|^Authors|')){
                  .[2:length(.)]
                } else {
                  .
                }
              } %>%
              (function(y){
                r = (1:length(y))[str_detect(y, regex('^\\d|^keywords|^department|^contact|^school^dept\\.', ignore_case = T))][1] - 1 
                if(is.na(r)){
                  y
                } else {
                  y[1:r]
                } 
              })
          } else {
            NA
          }
     })
    }))

#138, 137, 151, 154, 129, 124, 116, 107, 97, 80, 73, , 70, 60, 24
