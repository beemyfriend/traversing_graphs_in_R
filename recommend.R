library(tidyverse)
library(igraph)
library(magrittr)

links <- read_csv('traversing_graphs_in_R/Data/ml-latest-small/links.csv')
movies <- read_csv('traversing_graphs_in_R/Data/ml-latest-small/movies.csv')
ratings <- read_csv('traversing_graphs_in_R/Data/ml-latest-small/ratings.csv')
tags <- read_csv('traversing_graphs_in_R/Data/ml-latest-small/tags.csv')



movie_genre_edges <- movies %>%
  mutate(genres = str_split(genres, '\\|')) %>%
  unnest() %>%
  select(title, genres) %>%
  rename(from =title,
         to = genres) %>%
  mutate(type = 'HAS GENRE')

user_movie_edges <- ratings %>% 
  left_join(movies) %>%
  select(userId, title, rating, timestamp) %>%
  mutate(userId = str_c('USER:', userId)) %>%
  rename(from = userId,
         to = title) %>%
  mutate(type = 'RATED')

user_tag_edges <- tags %>%
  left_join(movies) %>%
  select(userId, tag, title) %>%
  mutate(userId = str_c('USER:', userId)) %>%
  rename(from = userId,
         to = tag,
         info = title) %>%
  mutate(type = 'USED TAG')

movie_tag_edges <- tags %>%
  left_join(movies) %>%
  select(title, tag, userId) %>%
  mutate(userId = str_c('USER:', userId)) %>%
  rename(from = title,
         to = tag, 
         info = userId) %>%
  mutate(type = 'WAS TAGGED')

el <- ls() %>%
  .[str_detect(., '_edges$')] %>%
  map(get) %>%
  bind_rows

movie_g <- graph_from_data_frame(el, T)

movie_g <- movie_g %>%
  E() %>%
  .[type == 'RATED'] %>%
  ends(movie_g, .) %>%
  (function(x){
    movie_g %>%
      set_vertex_attr('type', x[,1], 'USER') %>%
      set_vertex_attr('type', x[,2], 'MOVIE')
  }) %>%
  (function(x){
    x %>%
      E() %>%
      .[type == 'WAS TAGGED'] %>%
      head_of(x, .) %>%
      unique() %>%
      set_vertex_attr(x, 'type', ., 'TAG')
  }) %>%
  (function(x){
    x %>%
      E() %>%
      .[type == 'HAS GENRE'] %>%
      head_of(x, .) %>%
      unique() %>%
      set_vertex_attr(x, 'type', ., 'GENRE')
  }) %>%
  (function(x){
    x %>%
      V() %>%
      .[is.na(type)] %>%
      set_vertex_attr(x, 'type', ., 'MOVIE')
  })

movie_g %>%
  V() %>%
  .[type == 'MOVIE'] %>%
  map(function(x){
    E(movie_g)[x %--% V(movie_g)] %>%
      .[type == 'RATED']
  })
