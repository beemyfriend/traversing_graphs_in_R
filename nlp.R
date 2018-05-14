library(igraph)
library(tidyverse)
library(openNLP)
library(NLP)

g2016 <- read_graph('traversing_graphs_in_R/Data/g2016.graphml', 'graphml')
g2016 <- read_graph('Data/g2016.graphml', 'graphml')
sent_token_annotator <- Maxent_Sent_Token_Annotator()
word_token_annotator <- Maxent_Word_Token_Annotator()
pos_tag_annotator <- Maxent_POS_Tag_Annotator()

V(g2016)
test <- g2016  %>%
  (function(x){
    set_vertex_attr(x,
                    'abstract',
                    V(x)[nodeType == 'ABSTRACT'],
                    V(x)[nodeType == 'ABSTRACT']$pageBody  %>%
                      str_extract('(?<=Abstract:).+(?=Keywords:)') %>%
                      str_trim() %>%
                      str_replace_all('(?<=\\w)- (?=\\w)', ''))
    })

write_graph(test, 'Data/g2016_abstract.graphml', 'graphml')
abstracts <- V(g2016)[nodeType == 'ABSTRACT'] %>%
  .$pageBody %>%
  str_extract('(?<=Abstract:).+(?=Keywords:)') %>%
  str_trim() %>%
  str_replace_all('(?<=\\w)- (?=\\w)', '') %>%
  map(function(x){
    s <- as.String(x)
    a <- annotate(s , list(sent_token_annotator, word_token_annotator, pos_tag_annotator)) %>%
      {annotations_in_spans(subset(., type == 'word'),
                           subset(., type == 'sentence'))}
  })


index <- 3
s <- V(g2016)[nodeType == 'ABSTRACT']$pageBody[[index]] %>%
  str_extract('(?<=Abstract:).+(?=Keywords:)') %>%
  str_trim() %>%
  str_replace_all('(?<=\\w)- (?=\\w)', '') %>%
  as.String()



test <- abstracts[[index]]
# test2 <- map(test, function(x){
#   lapply(x, function(y){
#     original <- s[y] %>%
#       str_to_upper()
#     st <- s[y] %>%
#       str_to_lower() %>%
#       SnowballC::wordStem()
#     pos <- y$features[[1]]$POS
#     tibble(
#       original = original,
#       stem = st,
#       pos = pos
#     )
#   }) %>%
#     bind_rows() %>%
#     rbind(tibble(original = 'BEGIN_SENT', stem = NA, pos = NA),
#           .,
#           tibble(original = 'END_SENT', stem = NA, pos = NA))%>%
#     mutate(order = 1:nrow(.)) #%>%
#     # filter(str_detect(pos, 'NN.?|JJ.?')) %>%
#     # mutate(to = lapply(order, function(y){
#     #   filter(., order %in% c(y +1, y + 2))
#     # })) %>% 
#     # unnest() %>%
#     # mutate(distance = order1 - order) %>%
#     # select(original, original1, distance)
# }) #%>%
#   # bind_rows() %>%
#   # group_by(original, original1) %>%
#   # summarize(
#   #   distance = min(distance),
#   #   connections = n()
#   # ) -> test2
# 


test2 <- map(test, function(x){
  sapply(x, function(y){
    original <- s[y] %>%
      str_to_upper()
    pos <- y$features[[1]]$POS
    str_c(pos, ':', original)
    # tibble(
    #   original = original,
    #   pos = pos
    # )
  }) %>%
    c('BEGIN_SENT', ., 'END_SENT') %>%
    {
      tibble(from = .[1:(length(.)-1)],
             to = .[2:length(.)])
    } %>%
    mutate(order = 1:nrow(.),
           type = 'next')
}) %>%
  enframe(name = 'sentence') %>%
  unnest() %>%
  select(from, to, sentence, order, type)



g_test <- graph_from_data_frame(test2, T) 

g_textRank <- g_test %>%
  {. - V(.)[!str_detect(name, '^NN|^JJ')]} 

top_third <- page_rank(g_textRank)$vector %>%
  sort(T) %>%
  .[1:(length(.)/3)]

g_test %>%
{. - V(.)[!name %in% names(top_third)]} %>%
  plot(
    vertex.size = 0,
    vertex.label.cex = .7,
    edge.arrow.size = .5
  )

g_textRank2 <- V(g_test) %>%
  ego(g_test, 2, ., 'out') %>%
  map(function(x){
    if(length(x) == 3 && names(x)[3] != 'END_SENT' && names(x)[1] != 'BEGIN_SENT'){
      names(x)[c(1, 3)]
    }
  }) %>%
  unlist %>%
  {g_test + edges(., type = 'close')} %>%
  {. - V(.)[!str_detect(name, '^NN|^JJ')]}

top_third <- page_rank(g_textRank2)$vector %>%
  sort(T) %>%
  .[1:(length(.)/3)]

g_test %>%
  {. - V(.)[!name %in% names(top_third)]} %>%
  {. - E(.)[type != 'next']} %>%
  plot(
    vertex.label.cex = .7,
    vertex.size = 0,
    edge.arrow.size = .5
  )

V(g2016)[nodeType == 'ABSTRACT'][index]$pageBody
%>%
  ego(g2016, 1, ., 'out')
