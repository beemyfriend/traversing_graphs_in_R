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
  }) %>%
  (function(x){
    E(x)[V(x)[type == 'MOVIE'] %<-% V(x)[type == 'USER']] %>%
      subgraph.edges(x, .) %>%
      as_data_frame() %>%
      group_by(to) %>%
      summarize(ave_rating = mean(rating)) %>%
      {set_vertex_attr(x, 'ave_rating', .$to, .$ave_rating)}
  })

movie_g %>%
  V() %>%
  .[type == 'MOVIE'] %>%
  .[1:20] %>%
  incident_edges(movie_g, .)

movie_g %>%
  {. - E(.)[type != 'RATED']} %>%
  {. - V(.)[degree(.) < 1]} %>%
  {
    tibble(
      movie = head_of(., E(.))$name,
      rating = E(.)$rating
      ) %>%
      group_by(movie) %>%
      summarize(
        ave_rating = mean(rating),
        num_rates = n()
      )
  } %>%
  arrange(desc(ave_rating), desc(num_rates)) %>%
  filter(num_rates >= 10)

movie_g %>%
  V() %>%
  .[str_detect(name, 'Godfather, The|Shawshank Redemption')] %>%
  adjacent_vertices(movie_g, ., 'in') %>%
  do.call(c, .)%>%
  .[type == 'USER'] %>%
  unique %>%
  {E(movie_g)[. %--% V(movie_g)[type == 'MOVIE']]} %>%
  {movie_g - (E(movie_g)[!E(movie_g) %in% .])} %>%
  (function(x){
    edge.attributes(x) %>%
      as.tibble() %>%
      mutate(
        tail = tail_of(x, E(x))$name,
        head = head_of(x, E(x))$name
      )
  }) %>%
  filter(tail== 'USER:443')
  group_by(tail) %>%
  summarize(
    ave_rating = mean(rating),
    num_rates = n()
  ) %>%
  arrange(desc(ave_rating), desc(num_rates)) 

movie_g %>%
  {E(.)['USER:443' %--% V(.)[type == 'MOVIE']]} %>%
  head_of(movie_g, .) %>%
  {E(movie_g)[. %--% V(movie_g)[type == 'USER']]} %>%
  .[rating >= 4] %>%
  {movie_g - E(movie_g)[!E(movie_g) %in% .]} %>%
  degree(.,V(.)[type == 'USER']) %>%
  sort(T) %>%
  .[1:5] %>%
  names %>%
  {V(movie_g)[name %in% .]} %>%
  {E(movie_g)[. %--% V(movie_g)[type == 'MOVIE']]} %>%
  subgraph.edges(movie_g, .) %>%
  {. - V(.)[degree(.) < 4]} %>%
  {. - V(.)[ends(., E(.)['USER:443' %--% V(.)]) %>% unlist %>% unique]} %>%
  (function(x){
    #info <- x %>%
    x %>%
      as_data_frame() %>%
      group_by(to) %>%
      summarize(ave_rating = mean(rating)) %>%
      arrange(desc(ave_rating))
    
    #set_vertex_attr(x, 'ave_rating', info$to, info$ave_rating)
  }) 


