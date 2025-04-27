# RAG Chatbot with R Shiny
# This app allows users to upload PDFs, search via similarity, and chat with the documents

# Load required libraries
library(shiny)
library(shinydashboard)
library(text2vec)
# gptstudio is optional, we have a fallback implementation in retriever.R
# library(gptstudio)
library(pdftools)
library(httr)
library(jsonlite)

# Source utility functions
source("utils/pdf_reader.R")
source("utils/embedder.R")
source("utils/retriever.R")

# Define UI
ui <- dashboardPage(
  dashboardHeader(title = "RAG Chatbot"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Chat", tabName = "chat", icon = icon("comments")),
      menuItem("Upload", tabName = "upload", icon = icon("upload"))
    )
  ),
  
  dashboardBody(
    tabItems(
      # Upload tab
      tabItem(
        tabName = "upload",
        fluidRow(
          box(
            title = "Upload PDFs",
            width = 12,
            fileInput("pdf_files", "Select PDF Files",
                     multiple = TRUE,
                     accept = c("application/pdf")),
            actionButton("process_button", "Process PDFs", 
                         icon = icon("cogs"),
                         class = "btn-primary")
          )
        ),
        fluidRow(
          box(
            title = "Uploaded Documents",
            width = 12,
            tableOutput("pdf_list")
          )
        )
      ),
      
      # Chat tab
      tabItem(
        tabName = "chat",
        fluidRow(
          box(
            title = "Chat with your PDFs",
            width = 12,
            div(
              id = "chat_history",
              style = "overflow-y: scroll; height: 400px; border: 1px solid #ddd; padding: 10px; margin-bottom: 15px;",
              uiOutput("chat_messages")
            ),
            div(
              style = "display: flex;",
              textInput("chat_input", NULL, width = "90%", placeholder = "Type your question here..."),
              actionButton("send_button", "Send", icon = icon("paper-plane"), 
                          style = "margin-left: 10px;", 
                          class = "btn-primary")
            )
          )
        )
      )
    )
  )
)

# Define server logic
server <- function(input, output, session) {
  
  # Reactive values to store PDF data and embeddings
  pdf_data <- reactiveVal(list())
  embedding_model <- reactiveVal(NULL)
  chat_history <- reactiveVal(list())
  
  # Process uploaded PDFs
  observeEvent(input$process_button, {
    req(input$pdf_files)
    
    # Show processing message
    showModal(modalDialog(
      title = "Processing",
      "Reading PDFs and generating embeddings. This may take a moment...",
      footer = NULL
    ))
    
    # Get the uploaded file paths
    file_paths <- input$pdf_files$datapath
    file_names <- input$pdf_files$name
    
    # Process PDFs and create embeddings
    pdf_texts <- lapply(file_paths, read_pdf)
    
    # Initialize the embedding model if not already done
    if (is.null(embedding_model())) {
      embedding_model(initialize_embedder())
    }
    
    # Create document chunks and their embeddings
    all_chunks <- list()
    for (i in seq_along(pdf_texts)) {
      chunks <- create_chunks(pdf_texts[[i]])
      chunk_embeddings <- embed_chunks(chunks, embedding_model())
      
      for (j in seq_along(chunks)) {
        all_chunks[[length(all_chunks) + 1]] <- list(
          text = chunks[j],
          embedding = chunk_embeddings[j, ],
          source = file_names[i],
          chunk_id = j
        )
      }
    }
    
    # Store the processed data
    pdf_data(all_chunks)
    
    # Close the modal
    removeModal()
    
    # Notify user
    showNotification("PDFs processed successfully!", type = "message")
  })
  
  # Display uploaded PDFs
  output$pdf_list <- renderTable({
    req(pdf_data())
    
    # Count chunks per document
    doc_summary <- table(sapply(pdf_data(), function(x) x$source))
    
    # Create a dataframe for display
    data.frame(
      Document = names(doc_summary),
      Chunks = as.numeric(doc_summary)
    )
  })
  
  # Send message and get response
  observeEvent(input$send_button, {
    req(input$chat_input, pdf_data())
    
    user_query <- input$chat_input
    
    # Add user message to chat history
    history <- chat_history()
    history[[length(history) + 1]] <- list(
      role = "user",
      content = user_query
    )
    chat_history(history)
    
    # Clear input field
    updateTextInput(session, "chat_input", value = "")
    
    # Embed the query
    query_embedding <- embed_query(user_query, embedding_model())
    
    # Retrieve relevant document chunks
    relevant_chunks <- retrieve_chunks(query_embedding, pdf_data(), top_k = 3)
    
    # Format context for the model
    context <- paste(sapply(relevant_chunks, function(chunk) {
      paste0("From document '", chunk$source, "':\n", chunk$text)
    }), collapse = "\n\n")
    
    # Construct the prompt for GPT
    prompt <- paste0(
      "Based on the following documents, please answer this question: ", 
      user_query, 
      "\n\nRelevant documents:\n", 
      context
    )
    
    # Call GPT API
    gpt_response <- call_gpt(prompt)
    
    # Add assistant response to chat history
    history <- chat_history()
    history[[length(history) + 1]] <- list(
      role = "assistant",
      content = gpt_response
    )
    chat_history(history)
  })
  
  # Render chat messages
  output$chat_messages <- renderUI({
    history <- chat_history()
    
    if (length(history) == 0) {
      return(div(
        style = "text-align: center; color: #888; margin-top: 150px;",
        h4("Upload documents and ask questions to get started!")
      ))
    }
    
    message_elements <- lapply(history, function(msg) {
      if (msg$role == "user") {
        div(
          style = "margin-bottom: 15px;",
          div(
            style = "background-color: #DCF8C6; padding: 10px; border-radius: 10px; display: inline-block; float: right; max-width: 80%;",
            p(msg$content)
          ),
          div(style = "clear: both;")
        )
      } else {
        div(
          style = "margin-bottom: 15px;",
          div(
            style = "background-color: #F1F0F0; padding: 10px; border-radius: 10px; display: inline-block; float: left; max-width: 80%;",
            p(msg$content)
          ),
          div(style = "clear: both;")
        )
      }
    })
    
    do.call(tagList, message_elements)
  })
}

# Run the app
shinyApp(ui, server) 