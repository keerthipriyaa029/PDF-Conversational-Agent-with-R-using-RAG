# Embedder utility functions
# Functions to create and manage embeddings using text2vec

#' Initialize and prepare the embedder model
#'
#' @return The embedder model object
initialize_embedder <- function() {
  # Create vocabulary from a simple tokenizer
  prep_fun <- function(x) {
    x <- tolower(x)
    # Remove punctuation and special characters
    x <- gsub("[^[:alnum:][:space:]]", " ", x)
    # Remove extra whitespace
    x <- gsub("\\s+", " ", x)
    x <- trimws(x)
    return(x)
  }
  
  # Create the tokenizer
  tok_fun <- function(x) {
    tokens <- unlist(strsplit(x, "\\s+"))
    # Remove very short tokens
    tokens <- tokens[nchar(tokens) > 2]
    return(tokens)
  }
  
  # Create a model based on GloVe embeddings using text2vec
  
  # First create the vocabulary
  create_vocab <- function(tokens) {
    vocabulary <- text2vec::create_vocabulary(tokens)
    vocabulary <- text2vec::prune_vocabulary(vocabulary, 
                                           term_count_min = 2, 
                                           doc_proportion_max = 0.7)
    return(vocabulary)
  }
  
  # Create temporary tokens for the initial model (will be overridden with actual document text)
  temp_tokens <- list(tok_fun(prep_fun("This is a temporary document to initialize the model")))
  vocabulary <- create_vocab(temp_tokens)
  
  # Create term co-occurrence matrix and train GloVe model
  vectorizer <- text2vec::vocab_vectorizer(vocabulary)
  
  # Create GloVe model
  model <- list(
    prep_fun = prep_fun,
    tok_fun = tok_fun,
    create_vocab = create_vocab,
    vectorizer = vectorizer,
    dim = 100  # Dimension of the embedding vectors
  )
  
  return(model)
}

#' Embed a list of text chunks
#'
#' @param chunks List of text chunks to embed
#' @param model The embedder model
#' @return Matrix of embeddings
embed_chunks <- function(chunks, model) {
  # Preprocess chunks
  preprocessed_chunks <- lapply(chunks, model$prep_fun)
  
  # Tokenize
  tokenized_chunks <- lapply(preprocessed_chunks, model$tok_fun)
  
  # Create vocabulary from actual document tokens
  vocabulary <- model$create_vocab(tokenized_chunks)
  
  # Update the vectorizer with the document vocabulary
  vectorizer <- text2vec::vocab_vectorizer(vocabulary)
  
  # Create document-term matrix
  dtm <- text2vec::create_dtm(tokenized_chunks, vectorizer)
  
  # Normalize to unit length
  l2_norm <- sqrt(rowSums(dtm^2))
  # Handle zero vectors
  l2_norm[l2_norm == 0] <- 1
  
  normalized_dtm <- dtm / l2_norm
  
  return(normalized_dtm)
}

#' Embed a single query
#'
#' @param query The query text to embed
#' @param model The embedder model
#' @return Vector of query embedding
embed_query <- function(query, model) {
  # Preprocess
  preprocessed_query <- model$prep_fun(query)
  
  # Tokenize
  tokenized_query <- list(model$tok_fun(preprocessed_query))
  
  # Create document-term matrix for the query
  vectorizer <- model$vectorizer
  
  # Create DTM
  query_dtm <- text2vec::create_dtm(tokenized_query, vectorizer)
  
  # Normalize to unit length
  l2_norm <- sqrt(sum(query_dtm^2))
  # Handle zero vector
  if (l2_norm == 0) l2_norm <- 1
  
  normalized_query <- query_dtm / l2_norm
  
  return(normalized_query)
} 