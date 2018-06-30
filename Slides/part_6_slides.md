Recommendations
========================================================
author: 
date: 
autosize: true

<style>
.small-code pre code {
  font-size: 1em;
}
</style>



MovieLens Data Set
========================================================
We will make recommendations for people who have rated movies in MovieLens dataset provided by the [GroupLens group a the University of Minnesota](https://grouplens.org/datasets/movielens/)

MovieLens Data Set - Links
=====



```r
head(links)
```

```
# A tibble: 6 x 3
  movieId imdbId  tmdbId
    <int> <chr>    <int>
1       1 0114709    862
2       2 0113497   8844
3       3 0113228  15602
4       4 0114885  31357
5       5 0113041  11862
6       6 0113277    949
```

MovieLens Data Set - Movies
===
class:small-code

```r
head(movies)
```

```
# A tibble: 6 x 3
  movieId title                              genres                       
    <int> <chr>                              <chr>                        
1       1 Toy Story (1995)                   Adventure|Animation|Children…
2       2 Jumanji (1995)                     Adventure|Children|Fantasy   
3       3 Grumpier Old Men (1995)            Comedy|Romance               
4       4 Waiting to Exhale (1995)           Comedy|Drama|Romance         
5       5 Father of the Bride Part II (1995) Comedy                       
6       6 Heat (1995)                        Action|Crime|Thriller        
```

MovieLens Data Set - Ratings
===

```r
head(ratings)
```

```
# A tibble: 6 x 4
  userId movieId rating  timestamp
   <int>   <int>  <dbl>      <int>
1      1      31   2.50 1260759144
2      1    1029   3.00 1260759179
3      1    1061   3.00 1260759182
4      1    1129   2.00 1260759185
5      1    1172   4.00 1260759205
6      1    1263   2.00 1260759151
```

MovieLens Data Set - Tags
===
class:small-code

```r
head(tags)
```

```
# A tibble: 6 x 4
  userId movieId tag                      timestamp
   <int>   <int> <chr>                        <int>
1     15     339 sandra 'boring' bullock 1138537770
2     15    1955 dentist                 1193435061
3     15    7478 Cambodia                1170560997
4     15   32892 Russian                 1170626366
5     15   34162 forgettable             1141391765
6     15   35957 short                   1141391873
```

MovieLens Data Set - Edges
====
class:small-code

```r
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
```

MovieLens Data Set - Edges 
====
class:small-code

```r
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
```

MovieLens - Knowledge Graph
===
class:small-code

```r
movie_g <- graph_from_data_frame(el, T)
movie_g %>%
  summary()
```

```
IGRAPH acdc002 DN-- 10395 122936 -- 
+ attr: name (v/c), type (e/c), info (e/c), rating (e/n),
| timestamp (e/n)
```

MovieLens - Knowledge Graph
====
class:small-code

```r
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
  }) 
```

MovieLens - Knowledge Graph
===
class:small-code

```r
movie_g <- movie_g %>%
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
```


MovieLens - What Movies Stand Out?
====
class:small-code

```r
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
```

```
# A tibble: 2,245 x 3
   movie                               ave_rating num_rates
   <chr>                                    <dbl>     <int>
 1 Best Years of Our Lives, The (1946)       4.64        11
 2 Inherit the Wind (1960)                   4.54        12
 3 Godfather, The (1972)                     4.49       200
 4 Shawshank Redemption, The (1994)          4.49       311
 5 Tom Jones (1963)                          4.46        12
 6 Gladiator (1992)                          4.45        11
 7 On the Waterfront (1954)                  4.45        29
 8 When We Were Kings (1996)                 4.44        16
 9 All About Eve (1950)                      4.43        38
10 Ran (1985)                                4.42        26
# ... with 2,235 more rows
```

MovieLens - Let's pull out those movies
=====
class:small-code

```r
explore <- movie_g %>%
  V() %>%
  .[str_detect(name, 'Godfather, The|Shawshank Redemption')] 

explore
```

```
+ 2/10395 vertices, named, from acdc002:
[1] Shawshank Redemption, The (1994) Godfather, The (1972)           
```

MovieLens - Who rated those movies?
=====
class:small-code

```r
explore %<>%
  adjacent_vertices(movie_g, ., 'in') %>%
  do.call(c, .) %>%
  .[type == 'USER'] %>%
  unique 

explore
```

```
+ 382/10395 vertices, named, from acdc002:
  [1] Shawshank Redemption, The (1994).USER:3  
  [2] Shawshank Redemption, The (1994).USER:7  
  [3] Shawshank Redemption, The (1994).USER:8  
  [4] Shawshank Redemption, The (1994).USER:9  
  [5] Shawshank Redemption, The (1994).USER:10 
  [6] Shawshank Redemption, The (1994).USER:13 
  [7] Shawshank Redemption, The (1994).USER:15 
  [8] Shawshank Redemption, The (1994).USER:16 
  [9] Shawshank Redemption, The (1994).USER:17 
 [10] Shawshank Redemption, The (1994).USER:19 
+ ... omitted several vertices
```

MovieLens - What other movies are they watching?
====
class:small-code

```r
explore %<>%
  {E(movie_g)[. %--% V(movie_g)[type == 'MOVIE']]} %>%
  {movie_g - (E(movie_g)[!E(movie_g) %in% .])}

explore 
```

```
IGRAPH f8a15c4 DN-B 10395 78296 -- 
+ attr: name (v/c), type (v/c), ave_rating (v/n), type (e/c), info
| (e/c), rating (e/n), timestamp (e/n)
+ edges from f8a15c4 (vertex names):
 [1] USER:3->Indian in the Cupboard, The (1995)
 [2] USER:3->Braveheart (1995)                 
 [3] USER:3->Heavenly Creatures (1994)         
 [4] USER:3->Major Payne (1995)                
 [5] USER:3->Pulp Fiction (1994)               
 [6] USER:3->Shawshank Redemption, The (1994)  
 [7] USER:3->Flintstones, The (1994)           
+ ... omitted several edges
```

MovieLens- (preperation)
====
class:small-code

```r
explore %<>%
  (function(x){
    edge.attributes(x) %>%
      as.tibble() %>%
      mutate(
        tail = tail_of(x, E(x))$name,
        head = head_of(x, E(x))$name
      )
  }) 

explore
```

```
# A tibble: 78,296 x 6
   type  info  rating  timestamp tail   head                              
   <chr> <chr>  <dbl>      <int> <chr>  <chr>                             
 1 RATED <NA>    3.00 1298861675 USER:3 Indian in the Cupboard, The (1995)
 2 RATED <NA>    4.00 1298922049 USER:3 Braveheart (1995)                 
 3 RATED <NA>    3.50 1298861637 USER:3 Heavenly Creatures (1994)         
 4 RATED <NA>    3.00 1298861761 USER:3 Major Payne (1995)                
 5 RATED <NA>    4.50 1298862418 USER:3 Pulp Fiction (1994)               
 6 RATED <NA>    5.00 1298862121 USER:3 Shawshank Redemption, The (1994)  
 7 RATED <NA>    2.50 1298861589 USER:3 Flintstones, The (1994)           
 8 RATED <NA>    5.00 1298862167 USER:3 Forrest Gump (1994)               
 9 RATED <NA>    2.50 1298923242 USER:3 Speed (1994)                      
10 RATED <NA>    3.00 1298862528 USER:3 Schindler's List (1993)           
# ... with 78,286 more rows
```


MovieLens - What do we know about these raters?
====
class:small-code

```r
explore %<>%
  group_by(tail) %>%
  summarize(
    ave_rating = mean(rating),
    num_rates = n()
  ) %>%
  arrange(desc(ave_rating), desc(num_rates)) 

explore
```

```
# A tibble: 382 x 3
   tail     ave_rating num_rates
   <chr>         <dbl>     <int>
 1 USER:443       4.85        40
 2 USER:298       4.80        75
 3 USER:622       4.73        31
 4 USER:446       4.62        25
 5 USER:89        4.59        66
 6 USER:656       4.52       128
 7 USER:454       4.50        27
 8 USER:230       4.47        94
 9 USER:544       4.47       268
10 USER:242       4.47       399
# ... with 372 more rows
```

MovieLens - Who Shares a Rater's Movie Interest?
=====
class:small-code

```r
explore2 <- movie_g %>%
  {E(.)['USER:443' %--% V(.)[type == 'MOVIE']]} %>%
  .[rating >= 4] %>%
  head_of(movie_g, .) %>%
  {E(movie_g)[. %--% V(movie_g)[type == 'USER']]} %>%
  .[rating >= 4] 

explore2
```

```
+ 2890/122936 edges from acdc002 (vertex names):
 [1] USER:2->Terminator 2: Judgment Day (1991)                    
 [2] USER:3->Shawshank Redemption, The (1994)                     
 [3] USER:3->Forrest Gump (1994)                                  
 [4] USER:4->Star Wars: Episode IV - A New Hope (1977)            
 [5] USER:4->Forrest Gump (1994)                                  
 [6] USER:4->Blade Runner (1982)                                  
 [7] USER:4->Terminator 2: Judgment Day (1991)                    
 [8] USER:4->Die Hard (1988)                                      
 [9] USER:4->Monty Python and the Holy Grail (1975)               
[10] USER:4->Star Wars: Episode V - The Empire Strikes Back (1980)
+ ... omitted several edges
```


MovieLens - What movies do these people like?
===
class:small-code

```r
explore2 %<>%
  (function(x){
    similar_users <- tail_of(movie_g, x)

    movie_g %>%
      {. - E(.)[type != 'RATED']} %>%
      {. - E(.)[E(.) %in% x]} %>%
      {. - V(.)[!V(.)[type == 'USER'] %in% similar_users]}
  }) 

explore2
```

```
IGRAPH 225a19a DN-B 8547 63656 -- 
+ attr: name (v/c), type (v/c), ave_rating (v/n), type (e/c), info
| (e/c), rating (e/n), timestamp (e/n)
+ edges from 225a19a (vertex names):
[1] USER:1->Dangerous Minds (1995)                        
[2] USER:1->Dumbo (1941)                                  
[3] USER:1->Sleepers (1996)                               
[4] USER:1->Escape from New York (1981)                   
[5] USER:1->Cinema Paradiso (Nuovo cinema Paradiso) (1989)
[6] USER:1->Deer Hunter, The (1978)                       
[7] USER:1->Ben-Hur (1959)                                
+ ... omitted several edges
```

MovieLens - Which of these Movies has the User not rated?
====
class:small-code

```r
explore2 %<>%
  (function(x){
    movies_rated <- x %>%
      E() %>%
      .['USER:443' %--% V(x)[type == 'MOVIE']] %>% 
      head_of(x, .)
    x - movies_rated 
  }) %>%
  degree(.,V(.)[type == 'MOVIE']) %>%
  sort(T) %>%
  .[1:5] 

explore2
```

```
    Pulp Fiction (1994)    Jurassic Park (1993) Schindler's List (1993) 
                    255                     222                     197 
           Fargo (1996)          Aladdin (1992) 
                    185                     183 
```

MovieLens - Sanity Check
====
class:small-code

```r
movie_g %>% 
  E() %>% 
  .['USER:443' %--% V(movie_g)[type == "MOVIE"]] %>%
  head_of(movie_g, .) %>% 
  .$name %>% sort
```

```
 [1] "50/50 (2011)"                                                                  
 [2] "Akira (1988)"                                                                  
 [3] "Aliens (1986)"                                                                 
 [4] "Animatrix, The (2003)"                                                         
 [5] "Blade Runner (1982)"                                                           
 [6] "Die Hard (1988)"                                                               
 [7] "FLCL (2000)"                                                                   
 [8] "Forrest Gump (1994)"                                                           
 [9] "Get Hard (2015)"                                                               
[10] "Ghost in the Shell (Kôkaku kidôtai) (1995)"                                    
[11] "Girl Who Leapt Through Time, The (Toki o kakeru shôjo) (2006)"                 
[12] "Gone Girl (2014)"                                                              
[13] "Grave of the Fireflies (Hotaru no haka) (1988)"                                
[14] "Gravity (2013)"                                                                
[15] "Guardians of the Galaxy (2014)"                                                
[16] "Howl's Moving Castle (Hauru no ugoku shiro) (2004)"                            
[17] "Indiana Jones and the Last Crusade (1989)"                                     
[18] "Kiki's Delivery Service (Majo no takkyûbin) (1989)"                            
[19] "Laputa: Castle in the Sky (Tenkû no shiro Rapyuta) (1986)"                     
[20] "Léon: The Professional (a.k.a. The Professional) (Léon) (1994)"                
[21] "Matrix, The (1999)"                                                            
[22] "Monty Python and the Holy Grail (1975)"                                        
[23] "My Neighbor Totoro (Tonari no Totoro) (1988)"                                  
[24] "Nausicaä of the Valley of the Wind (Kaze no tani no Naushika) (1984)"          
[25] "Ninja Scroll (Jûbei ninpûchô) (1995)"                                          
[26] "Pan's Labyrinth (Laberinto del fauno, El) (2006)"                              
[27] "Perfect Blue (1997)"                                                           
[28] "Ponyo (Gake no ue no Ponyo) (2008)"                                            
[29] "Princess Mononoke (Mononoke-hime) (1997)"                                      
[30] "Prometheus (2012)"                                                             
[31] "Raiders of the Lost Ark (Indiana Jones and the Raiders of the Lost Ark) (1981)"
[32] "Shawshank Redemption, The (1994)"                                              
[33] "Silence of the Lambs, The (1991)"                                              
[34] "Spirited Away (Sen to Chihiro no kamikakushi) (2001)"                          
[35] "Star Wars: Episode IV - A New Hope (1977)"                                     
[36] "Star Wars: Episode V - The Empire Strikes Back (1980)"                         
[37] "Star Wars: Episode VI - Return of the Jedi (1983)"                             
[38] "Summer Wars (Samâ wôzu) (2009)"                                                
[39] "Terminator 2: Judgment Day (1991)"                                             
[40] "Wolf of Wall Street, The (2013)"                                               
```

Blogs To Look Out For
=====

Neo4j
[https://neo4j.com/blog/](https://neo4j.com/blog/)

Kelvin Lawrence
[http://kelvinlawrence.net/book/Gremlin-Graph-Guide.html](http://kelvinlawrence.net/book/Gremlin-Graph-Guide.html)

Jason Plurad
[https://twitter.com/pluradj](https://twitter.com/pluradj)
