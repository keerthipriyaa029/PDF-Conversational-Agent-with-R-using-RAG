# PDF Reader utility functions
# Functions to read and preprocess PDF documents

#' Read PDF file and extract text
#'
#' @param file_path Path to the PDF file
#' @return Character vector with text content
read_pdf <- function(file_path) {
  # Extract text from PDF
  tryCatch({
    # Read all pages from the PDF
    pdf_text <- pdftools::pdf_text(file_path)
    
    # Clean the extracted text
    pdf_text <- clean_pdf_text(pdf_text)
    
    return(pdf_text)
  }, error = function(e) {
    warning(paste("Error reading PDF file:", file_path, "-", e$message))
    return(character(0))
  })
}

#' Clean and normalize PDF text
#'
#' @param pdf_text Character vector with text content from a PDF
#' @return Cleaned character vector
clean_pdf_text <- function(pdf_text) {
  # Combine all pages into a single text
  combined_text <- paste(pdf_text, collapse = " ")
  
  # Remove excessive whitespace
  cleaned_text <- gsub("\\s+", " ", combined_text)
  
  # Trim leading and trailing whitespace
  cleaned_text <- trimws(cleaned_text)
  
  return(cleaned_text)
}

#' Split text into smaller, manageable chunks
#'
#' @param text Text to split into chunks
#' @param chunk_size Size of each chunk (in characters)
#' @param chunk_overlap Number of characters to overlap between chunks
#' @return Character vector of text chunks
create_chunks <- function(text, chunk_size = 1000, chunk_overlap = 200) {
  # If text is empty, return empty vector
  if (length(text) == 0 || nchar(text) == 0) {
    return(character(0))
  }
  
  # Split text into sentences (rough approximation)
  sentences <- unlist(strsplit(text, "(?<=\\.)\\s+", perl = TRUE))
  
  chunks <- character(0)
  current_chunk <- ""
  
  for (sentence in sentences) {
    # If adding this sentence would exceed chunk_size, store current chunk and start new one
    if (nchar(current_chunk) + nchar(sentence) > chunk_size && nchar(current_chunk) > 0) {
      chunks <- c(chunks, current_chunk)
      
      # Start new chunk with overlap from the previous chunk
      if (nchar(current_chunk) > chunk_overlap) {
        # Get last portion of previous chunk for overlap
        overlap_text <- substr(current_chunk, 
                              nchar(current_chunk) - chunk_overlap + 1, 
                              nchar(current_chunk))
        current_chunk <- overlap_text
      } else {
        current_chunk <- ""
      }
    }
    
    # Add the current sentence to the chunk
    current_chunk <- paste(current_chunk, sentence, sep = " ")
    current_chunk <- trimws(current_chunk)
  }
  
  # Add the last chunk if it's not empty
  if (nchar(current_chunk) > 0) {
    chunks <- c(chunks, current_chunk)
  }
  
  return(chunks)
} 