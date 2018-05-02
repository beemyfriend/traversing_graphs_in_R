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



######################################
### Key Phrase Extraction
#####################################

noKeywords <- page_body %>%
  filter(is.na(keywords),
         !is.na(pageNumber))

test <- noKeywords$pageBody[1] %>%
  str_split('\\n') %>%
  unlist %>%
  .[-c(1:6, 20)] %>%
  str_c(collapse = ' ') %>%
  str_replace('^Abstract:', '') %>%
  as.String()

pos_tag_annotator <- Maxent_POS_Tag_Annotator()
sent_token_annotator <- Maxent_Sent_Token_Annotator()
word_token_annotator <- Maxent_Word_Token_Annotator()
a <- annotate(test, list(sent_token_annotator, word_token_annotator, pos_tag_annotator))
aW <- subset(a, type ==  'word') 
aS <- test[subset(a, type == 'sentence')]

info <- annotations_in_spans(subset(a, type == 'word'),
                     subset(a, type == 'sentence'))

origWord <- test[info[[1]]] %>%
  str_to_lower()
stemmedWord <- tm::stemDocument(origWord)
taggedWord <- sprintf('%s:%s', stemmedWord, sapply(info[[1]]$features, '[[', 'POS'))
tag <- sapply(info[[1]]$features, '[[', 'POS')

abstractTextRank <- tibble(
  origWord,
  stemmedWord,
  taggedWord,
  tag
) %>%
  filter(!tag %in% c(',', '.', '-LRB-', '-RRB-')) %>%
  mutate(order = 1:nrow(.)) %>%
  filter(str_detect(tag, 'NN(.)?|JJ(.)?')) %>%
  {mutate(., connections = lapply(order, function(x){
    start = x +1
    end = x + 3
    filter(., order %in% start:end)
  }))}

wordNodeList <- abstractTextRank %>%
  select(taggedWord, origWord) %>%
  nest(origWord)

wordEdgeList <- abstractTextRank %>%
  select(taggedWord, connections) %>%
  rename(source = taggedWord) %>%
  unnest() %>%
  rename(target = taggedWord) %>%
  select(source, target) %>%
  count(source, target,sort = T)


abstractTextRank <- lapply(info, function(x){
  origWord <- test[x] %>%
    str_to_lower()
  stemmedWord <- tm::stemDocument(origWord)
  tag <- sapply(x$features, '[[', 'POS')
  taggedWord <- sprintf('%s:%s', stemmedWord, tag)
  
  tibble(
    origWord,
    stemmedWord,
    taggedWord,
    tag
  ) %>%
    filter(!tag %in% c(',', '.', '-LRB-', '-RRB-')) %>%
    mutate(order = 1:nrow(.)) %>%
    filter(str_detect(tag, 'NN(.)?|JJ(.)?')) %>%
    {mutate(., connections = lapply(order, function(y){
      start = y +1
      end = y + 4
      filter(., order %in% start:end)
    }))}
}) %>%
  bind_rows()

wordNodeList <- abstractTextRank %>%
  select(taggedWord, origWord) %>%
  nest(origWord)

wordEdgeList <- abstractTextRank %>%
  select(taggedWord, connections) %>%
  rename(source = taggedWord) %>%
  unnest() %>%
  rename(target = taggedWord) %>%
  select(source, target) %>%
  count(source, target,sort = T) %>%
  rename(weight = n)

g <- graph_from_data_frame(wordEdgeList, F, wordNodeList)

page_rank(g)$vector %>%
  sort(T) %>%
  head(ceiling(length(.)/3)) %>%
  names %>%
  induced_subgraph(g, .) %>%
  plot



#################################
##### Knowledge Graph 
#################################


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

library(igraph)

g <- graph_from_data_frame(edge_list, T, node_list)
 

V(g)$degree <- degree(g)
V(g) %>% 
  .[nodeType == 'KEYWORD'] %>% 
  .[degree == max(.$degree)] %>% 
  adjacent_vertices(g, ., 'in')  %>%
  {E(g)[.[[1]] %<-% V(g)]} %>%
  tail_of(g, .) %>%
  .$name %>%
  table() %>%
  .[. > 1] %>%
  names() %>%
  {V(g)[.]} %>%
  adjacent_vertices(g, .) %>%
  lapply(., function(x){
    x$abstractType
  })

V(g)[nodeType == 'AUTHOR'] %>%
  .[degree == max(degree)] %>%
  adjacent_vertices(g, .) %>%
  lapply(., function(x){
    x$pageBody %>% cat
  })
%>%
  do.call(c, .) %>%
  adjacent_vertices(g, .) 
