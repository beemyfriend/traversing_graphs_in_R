sapply(c('tidyverse', 'pdftools', 'igraph', 'NLP','openNLP'), library, character.only = T)
setwd('traversing_graphs_in_R/')

#####################
## Order of Operations
#####################

# load pdf file
# get text
# seperate toc from body of abstracts
# clean toc


#########################
## 2017
#########################

pdf_file <- 'useR! Abstracts/user2017.pdf'
text <- pdf_text(pdf_file)
toc <- text[2:22]
pages <- text[23:length(text)]
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
  pageNumber = str_trim(pageNumber) #%>%
  # as.numeric()
  temp = temp[[1]] %>%
    str_replace_all('\\-\\n\\s+', '') %>%
    str_replace_all('\\n\\s+', ' ') %>%
    str_trim() 
  title = temp[1] %>%
    str_to_upper()
  author = temp[2] %>%
    str_split('\\,(\\s*and\\b)?|\\band\\b') %>%
    .[[1]] %>%
    str_trim() %>%
    str_to_upper()
  
  tibble(
    title = title,
    author = author,
    pageNumber = pageNumber
  ) 
}) %>%
  bind_rows() %>%
  filter(!is.na(pageNumber)) %>%
  mutate(abstractType = sapply(pageNumber,function(x){
    if(as.numeric(x) < 162){
      'Talks'
    } else if(as.numeric(x) < 226){
      'Lightning Talks'
    } else {
      'Poster'
    }
  }))

toc_title_author

page_body <- tibble(
  pageNumber = str_extract(pages, '\\d+\\n$') %>% str_trim(),
  pageBody = str_replace(pages, '\\d+\\n$', '') %>% str_replace('useR! 2017 .+\\n', '') %>% str_trim(),
  keywords = str_extract(pageBody, regex('(?<=keywords:) .+\\n', ignore_case = T)) %>% str_to_upper() %>% str_split(',')
) %>%
  unnest() %>%
  mutate(keywords = str_trim(keywords))

abstract_book <- toc_title_author %>%
  left_join(page_body)

author_abstract = abstract_book %>%
  select(title, author) %>%
  distinct() %>%
  select(source = author,
         target = title) %>%
  filter(!is.na(source),
         !is.na(target)) %>%
  mutate(type = 'WROTE')

abstract_keyword = abstract_book %>%
  select(title, keywords) %>%
  distinct() %>% 
  rename(source = title,
         target = keywords) %>%
  filter(!is.na(source),
         !is.na(target)) %>%
  mutate(type = 'CONTAINS')

edge_list <- rbind(author_abstract, abstract_keyword) %>%
  filter(source != '', 
         target != '')

abstracts = abstract_book %>%
  select(title, pageBody, abstractType) %>%
  distinct() %>%
  rename(name = title) %>%
  mutate(nodeType = 'ABSTRACT')

author = abstract_book %>%
  select(author) %>%
  distinct() %>%
  rename(name = author) %>%
  mutate(nodeType = 'AUTHOR')

keywords = abstract_book %>%
  select(keywords) %>%
  distinct() %>%
  rename(name = keywords) %>%
  mutate(nodeType = 'KEYWORD')

node_list <- list(author, keywords, abstracts) %>% bind_rows %>% filter(name != '')

g2017 <- graph_from_data_frame(edge_list, T, node_list)
write_graph(g2017, 'Data/g2017.graphml', 'graphml')

############################
## 2016
#############################

# load pdf file
text <- pdf_text('useR! Abstracts/useR2016.pdf')
# seperate toc from body of abstracts


test <- toc[1] %>%
  str_split('\\n|\\s{3}') %>%
  unlist %>%
  str_trim() %>%
  .[!. %in% c('Contents', 'Part I:', 'Poster', '')] %>%
  .[11:19] %>%
  str_c('\\n') %>%
  as.String()
pos_tag_annotator <- Maxent_POS_Tag_Annotator()
sent_token_annotator <- Maxent_Sent_Token_Annotator()
word_token_annotator <- Maxent_Word_Token_Annotator()
a <- annotate(test, list(sent_token_annotator, word_token_annotator, pos_tag_annotator))
aW <- subset(a, type == 'word')
taggedWord <- sprintf('%s:%s', test[aW], sapply(aW$features, '[[', 'POS'))

toc <- pdf_toc('useR! Abstracts/useR2016.pdf')

title_info <- lapply(1:length(toc$children), function(i){
  talk_type = toc$children[[i]]$title
  talk_children = toc$children[[i]]$children
  lapply(1:length(talk_children), function(j){
    talk_title <- talk_children[[j]]$title
    talk_page <- switch(talk_type, "Poster" = ifelse(26 + j < 45, 26 + j, 26 + j + 1), "Lightning Talk" = ifelse(j+88 <106, j+88, j+89),  "Oral Presentation" = 134 + j)
    tibble(talk_type = talk_type,
           talk_title = talk_title,
           talk_page = talk_page)
  }) %>%
    bind_rows
}) %>%
  bind_rows %>%
  mutate(talk_page = as.integer(talk_page)) %>%
  mutate(talk_body = text[talk_page] %>%
           str_replace('^[^\\n]*\\n', '')) %>%
  mutate(talk_keywords = talk_body %>%
           str_replace_all('\\n',' ') %>%
           str_extract('(?<=Keywords:).+(?=\\s\\d{2,3}\\s$)'))

title_info <- title_info %>%
  mutate(talk_keywords = map2_chr(talk_page, talk_keywords, function(i, x){
    if(i %in% c(44, 105)){
      print(i + 1)
      text[i + 1] %>%
        str_replace_all('\\n', ' ') %>%
        str_extract('(?<=Keywords:).+(?=\\s\\d{2,3}\\s$)') 
    } else {
      x
    }
  })) 

toc <- text[9:25] %>% 
  str_split('\\n') %>%
  lapply(function(x){
    x <- x[2:(length(x) -2)]
  }) %>%
  unlist %>%
  .[!. %in% c("Part I:    Poster", "Part II:    Lightning Talk", "Part III:     Oral Presentation")]

title_authors <- map2_chr(title_info$talk_page, c(title_info$talk_title %>% .[2:length(.)], NA), function(i, x){
    toc_index <- (1:length(toc))[str_detect(toc, str_c('\\b', i, '$'))]
    if(is.na(x)){return(toc[(toc_index + 1):length(toc)] %>% str_c(collapse = ' '))}
    first_two <- str_split(x, ' ') %>% 
      unlist() %>%
      .[1:2] %>%
      str_c(collapse =' ')
    counter = 1
    authors <- c()
    print(start)
    while(!str_detect(toc[toc_index + counter], first_two)&&counter < 5){
      print(toc_index + counter)
      print(first_two)
      authors[counter] <- toc[toc_index + counter]
      counter = counter + 1
    }
    str_c(authors, collapse = ' ')
  })

title_info$title_authors <- title_authors

title_info <- title_info %>%
  mutate(title_authors = map2_chr(talk_page, title_authors, function(i, x){
    print(i)
    if(i %in% c(72, 90, 105, 113, 145, 170, 218)){
      switch(as.character(i), 
             '72' = 'Rudolf Debelak, Johanna Egle, Lena Köstering & Christoph P. Kaller',
             '90' = 'Allan Miller', 
             '105' = 'Gene Leynes & Tom Schenk', 
             '113'= 'Jan-Philipp Kolb', 
             '145' = 'Andrew M Redd',
             '170'= 'David Mark Smith', 
             '218' = 'David Ibarra & Josep Arnal')
    } else {
      x
    }
  })) 

abstract_book_2016 <- title_info %>%
  mutate(title_authors = str_split(title_authors, ',\\s(?!Jr\\.)|\\&')) %>%
  unnest() %>%
  mutate(title_authors = title_authors %>% str_trim %>% str_to_upper) %>%
  mutate(talk_keywords = talk_keywords %>%
           str_replace_all('- ', '') %>%
           str_split(',') %>%
           lapply(., function(x){x %>% str_trim %>% str_to_upper %>% .[. != '']})) %>%
  unnest() %>%
  mutate(talk_title = talk_title %>% stringi::stri_escape_unicode() %>% str_replace_all('\\\\u.{4}', '')) %>%
  mutate(talk_body = talk_body %>% str_replace_all('\\n', ' ') %>% stringi::stri_escape_unicode() %>% str_replace_all('\\\\u.{4}', ' '))


abstracts = abstract_book_2016 %>%
  select(talk_title, talk_body, talk_type) %>%
  distinct() %>%
  rename(name = talk_title,
         pageBody = talk_body,
         abstractType = talk_type) %>%
  mutate(nodeType = 'ABSTRACT')

author = abstract_book_2016 %>%
  select(title_authors) %>%
  distinct() %>%
  rename(name = title_authors) %>%
  mutate(nodeType = 'AUTHOR')

keywords = abstract_book_2016 %>%
  select(talk_keywords) %>%
  distinct() %>%
  rename(name = talk_keywords) %>%
  mutate(nodeType = 'KEYWORD')

node_list <- list(author, keywords, abstracts) %>% bind_rows %>% filter(name != '')


author_abstract = abstract_book_2016 %>%
    select(talk_title, title_authors) %>%
  distinct() %>%
  select(source = title_authors,
         target = talk_title) %>%
  filter(!is.na(source),
         !is.na(target)) %>%
  mutate(type = 'WROTE')

abstract_keyword = abstract_book_2016 %>%
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

g2016 <- graph_from_data_frame(edge_list, T, node_list)

#46, 140
write_graph(g2016, 'Data/g2016.graphml', 'graphml')
node_list$pageBody %>% .[!is.na(.)] %>% .[str_detect(., '0x19')]
node_list$
  
  