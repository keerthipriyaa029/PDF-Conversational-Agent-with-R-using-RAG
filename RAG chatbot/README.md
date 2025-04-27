# RAG (Retrieval Augmented Generation) with R

This is a minimal R Shiny app that allows users to upload PDFs, search through them via vector similarity, and chat with the documents using OpenAI GPT models.

## Features

- Upload multiple PDF documents
- Automatic text extraction and embedding
- Vector-based similarity search
- Chat interface powered by GPT models
- 100% implemented in R

## Requirements

- R 4.0.0 or higher
- Required packages:
  - shiny
  - shinydashboard
  - text2vec
  - gptstudio
  - pdftools

## Setup

1. Clone this repository
2. Install required packages:

```R
install.packages(c("shiny", "shinydashboard", "text2vec", "pdftools"))
remotes::install_github("JamesHWade/gptstudio")
```

3. Set your OpenAI API key:

```R
Sys.setenv(OPENAI_API_KEY = "your-openai-api-key")
```

Alternatively, create a `.env` file in the project root with:

```
OPENAI_API_KEY=your-openai-api-key
```

## Running the App

To run the app, simply open R in the project directory and execute:

```R
shiny::runApp()
```

Or run the app.R file directly from RStudio.

## How to Use

1. Navigate to the "Upload" tab and upload your PDF documents.
2. Click the "Process PDFs" button to extract text and generate embeddings.
3. Switch to the "Chat" tab to ask questions about the uploaded documents.
4. Type your query in the text box and press "Send" to get a response.

## How It Works

1. **PDF Upload & Processing**: 
   - The app extracts text from uploaded PDFs using `pdftools`.
   - The text is chunked into smaller segments for better retrieval.

2. **Embedding Generation**:
   - Document chunks are converted into vector embeddings using `text2vec`.
   - When you ask a question, it is also converted to a vector embedding.

3. **Similarity Search**:
   - The app finds the most relevant document chunks by calculating cosine similarity between your query and the document embeddings.

4. **Answer Generation**:
   - The most relevant document chunks are sent to OpenAI's GPT model along with your query.
   - GPT generates a response based on the context provided by these chunks.

## Project Structure

- `app.R` - Main Shiny app (combines UI + Server)
- `utils/`
  - `pdf_reader.R` - Functions to read and preprocess PDFs
  - `embedder.R` - Functions to embed text and queries
  - `retriever.R` - Functions to compute similarity and retrieve docs

## Limitations

- Uses a simple embedding method with text2vec
- All data is stored in memory, so very large document collections may cause performance issues
- Limited to the capabilities of the GPT model being used 