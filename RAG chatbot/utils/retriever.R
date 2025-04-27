# Retriever utility functions
# Functions to compute similarity and retrieve relevant documents

#' Calculate cosine similarity between two embeddings
#'
#' @param vec1 First embedding vector
#' @param vec2 Second embedding vector
#' @return Numeric similarity score between 0 and 1
cosine_similarity <- function(vec1, vec2) {
  # Ensure vectors have the same dimensions
  if (length(vec1) != length(vec2)) {
    stop("Vectors must have the same dimensions")
  }
  
  # Calculate dot product
  dot_product <- sum(vec1 * vec2)
  
  # Calculate magnitudes
  mag1 <- sqrt(sum(vec1^2))
  mag2 <- sqrt(sum(vec2^2))
  
  # Prevent division by zero
  if (mag1 == 0 || mag2 == 0) {
    return(0)
  }
  
  # Calculate cosine similarity
  similarity <- dot_product / (mag1 * mag2)
  
  return(similarity)
}

#' Retrieve the most relevant document chunks for a query
#'
#' @param query_embedding The embedding vector of the query
#' @param document_chunks List of document chunks with their embeddings
#' @param top_k Number of top chunks to retrieve
#' @return List of the most relevant document chunks
retrieve_chunks <- function(query_embedding, document_chunks, top_k = 3) {
  # If no document chunks, return empty list
  if (length(document_chunks) == 0) {
    return(list())
  }
  
  # Calculate similarity scores for each chunk
  similarity_scores <- numeric(length(document_chunks))
  
  for (i in seq_along(document_chunks)) {
    chunk_embedding <- document_chunks[[i]]$embedding
    similarity_scores[i] <- cosine_similarity(query_embedding, chunk_embedding)
  }
  
  # Sort chunks by similarity scores and get top_k
  if (length(similarity_scores) > 0) {
    # Get indices of top_k chunks
    top_indices <- order(similarity_scores, decreasing = TRUE)[1:min(top_k, length(similarity_scores))]
    
    # Get the top chunks
    top_chunks <- document_chunks[top_indices]
    
    return(top_chunks)
  } else {
    return(list())
  }
}

#' Call the GPT model using OpenAI API directly or gptstudio if available
#'
#' @param prompt The prompt to send to the GPT model
#' @return Character string with the model's response
call_gpt <- function(prompt) {
  # Try to get the API key from environment
  api_key <- Sys.getenv("OPENAI_API_KEY")
  
  # Check if API key is available
  if (api_key == "") {
    return("Error: OpenAI API key not found. Please set it with Sys.setenv(OPENAI_API_KEY = 'your-key')")
  }
  
  # First try with gptstudio if available
  if (requireNamespace("gptstudio", quietly = TRUE)) {
    tryCatch({
      # Call GPT API using gptstudio
      response <- gptstudio::gpt(
        prompt = prompt,
        model = "gpt-3.5-turbo",  # or any other available model
        max_tokens = 500,
        temperature = 0.7
      )
      
      # Extract and return the response text
      return(response$choices[[1]]$message$content)
    }, error = function(e) {
      message("Error using gptstudio: ", e$message)
      message("Falling back to direct OpenAI API call")
      # Fall back to direct API call
      return(call_gpt_direct(prompt, api_key))
    })
  } else {
    # Use direct API call method if gptstudio is not available
    return(call_gpt_direct(prompt, api_key))
  }
}

#' Direct implementation of OpenAI API call without gptstudio
#'
#' @param prompt The prompt to send to the GPT model
#' @param api_key OpenAI API key
#' @return Character string with the model's response
call_gpt_direct <- function(prompt, api_key) {
  if (!requireNamespace("httr", quietly = TRUE) || !requireNamespace("jsonlite", quietly = TRUE)) {
    # Install required packages if not available
    if (!requireNamespace("httr", quietly = TRUE)) {
      install.packages("httr", repos = "https://cloud.r-project.org/")
      library(httr)
    }
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
      install.packages("jsonlite", repos = "https://cloud.r-project.org/")
      library(jsonlite)
    }
  }
  
  library(httr)
  library(jsonlite)
  
  # Prepare the request body
  body <- list(
    model = "gpt-3.5-turbo",
    messages = list(
      list(
        role = "user",
        content = prompt
      )
    ),
    max_tokens = 500,
    temperature = 0.7
  )
  
  # Convert to JSON
  body_json <- jsonlite::toJSON(body, auto_unbox = TRUE)
  
  # Make the API request
  tryCatch({
    response <- httr::POST(
      url = "https://api.openai.com/v1/chat/completions",
      httr::add_headers(
        "Content-Type" = "application/json",
        "Authorization" = paste("Bearer", api_key)
      ),
      body = body_json
    )
    
    # Parse the response
    response_content <- httr::content(response, as = "text", encoding = "UTF-8")
    response_json <- jsonlite::fromJSON(response_content)
    
    # Extract the response text
    if (!is.null(response_json$choices) && length(response_json$choices) > 0) {
      return(response_json$choices[[1]]$message$content)
    } else {
      return(paste("Error: Unexpected API response format:", response_content))
    }
  }, error = function(e) {
    return(paste("Error calling OpenAI API:", e$message))
  })
} 