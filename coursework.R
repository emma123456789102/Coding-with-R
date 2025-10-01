# Load required libraries
library(tm)
library(topicmodels)
library(dplyr)
library(tidytext)
library(ggplot2)
library(zip)
library(broom)

# Helper Functions for Visualization
reorder_within <- function(x, by, within, fun = mean, sep = "___", ...) {
  new_x <- paste(x, within, sep = sep)
  stats::reorder(new_x, by, FUN = fun, ...)
}

scale_x_reordered <- function(...) {
  ggplot2::scale_x_discrete(labels = function(x) gsub("___.*$", "", x), ...)
}

# Function: Load Text Data
load_text_data <- function(file_path) {
  if (file.exists(file_path)) {
    if (grepl("\\.csv$", file_path)) {  # If the file is a CSV
      text_data <- read.csv(file_path, stringsAsFactors = FALSE)
      text_data <- unlist(text_data)  # Flatten if the CSV has a single column
    } else {  # If the file is plain text
      text_data <- readLines(file_path, encoding = "UTF-8", warn = FALSE)  # Suppress warnings
    }
    return(text_data)
  } else {
    stop("File not found.")
  }
}

# Function: Clean and Pre-process Text
clean_text <- function(text_data, custom_stopwords) {
  corpus <- Corpus(VectorSource(text_data))  # Convert text data to corpus
  
  # Replace empty documents with placeholders
  corpus <- tm_map(corpus, content_transformer(function(x) ifelse(nchar(x) == 0 | is.null(x), "placeholder", x)))
  
  # Basic Cleaning
  corpus <- tm_map(corpus, content_transformer(tolower))
  corpus <- tm_map(corpus, content_transformer(removePunctuation))
  corpus <- tm_map(corpus, removeNumbers)
  corpus <- tm_map(corpus, stripWhitespace)
  
  # Stop Words
  stopwords_combined <- c(stopwords("en"), custom_stopwords)
  corpus <- tm_map(corpus, removeWords, stopwords_combined)
  
  # Return cleaned corpus
  return(corpus)
}



# Function: Find and Display Common Words
find_common_words <- function(corpus, top_n = 10) {
  dtm <- DocumentTermMatrix(corpus)
  term_freq <- colSums(as.matrix(dtm))  # Get term frequencies
  
  # Sort terms by frequency
  term_freq_sorted <- sort(term_freq, decreasing = TRUE)
  
  # Select the top N terms
  common_words <- head(term_freq_sorted, n = top_n)
  
  # Convert to a data frame for easier visualization
  common_words_df <- data.frame(
    Word = names(common_words),
    Frequency = as.numeric(common_words),
    stringsAsFactors = FALSE
  )
  
  # Print the top common words
  print("Most Common Words:")
  print(common_words_df)
  
  # Optional: Plot the common words
  ggplot(common_words_df, aes(x = reorder(Word, -Frequency), y = Frequency)) +
    geom_bar(stat = "identity", fill = "skyblue") +
    labs(title = "Top Common Words", x = "Word", y = "Frequency") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
}


# Function: Write Descriptive Statistics
write_descriptive_stats <- function(corpus, output_path) {
  dtm <- DocumentTermMatrix(corpus)
  term_freq <- colSums(as.matrix(dtm))
  term_freq <- term_freq[term_freq > 1]  # Remove terms with frequency 0
  
  # Align term names with frequencies
  stats <- data.frame(Word = names(term_freq), Frequency = as.numeric(term_freq), stringsAsFactors = FALSE)
  
  # Ensure no empty or missing names
  stats <- stats[!is.na(stats$Word) & stats$Word != "", ]
  
  # Save most common words
  write.csv(stats, file = file.path(output_path, "descriptive_stats.csv"), row.names = FALSE)
  
  # Overall Statistics
  total_words <- sum(stats$Frequency)
  unique_words <- nrow(stats)
  summary <- paste("Total Words:", total_words, "\nUnique Words:", unique_words)
  writeLines(summary, con = file.path(output_path, "summary.txt"))
}

# Function: Perform Topic Modeling
perform_topic_modeling <- function(corpus, num_topics = 5) {
  dtm <- DocumentTermMatrix(corpus)
  
  # Remove rows with no terms
  non_empty_rows <- rowSums(as.matrix(dtm)) > 0
  dtm <- dtm[non_empty_rows, ]
  
  if (nrow(dtm) == 0) {
    stop("All documents are empty after preprocessing. Please check your input data and preprocessing steps.")
  }
  

  # Run LDA
  lda_model <- LDA(dtm, k = num_topics, control = list(seed = 1234))
  
  return(lda_model)
}



# Function: Output Topic Models to CSV
output_topic_models <- function(lda_model, output_path) {
  terms <- terms(lda_model, 10) # Get top 10 terms per topic
  topics <- data.frame(Topic = rep(1:nrow(terms), each = 10), Word = as.vector(terms))
  
  write.csv(topics, file = file.path(output_path, "topic_models.csv"), row.names = FALSE)
}

# Function: Visualize the Topic Model
visualize_topics <- function(lda_model, output_path) {
  beta <- tidy(lda_model, matrix = "beta")
  
  # Visualize top terms
  top_terms <- beta %>%
    group_by(topic) %>%
    top_n(10, beta) %>%
    ungroup() %>%
    arrange(topic, -beta)
  
  plot <- ggplot(top_terms, aes(reorder_within(term, beta, topic), beta, fill = factor(topic))) +
    geom_col(show.legend = FALSE) +
    facet_wrap(~topic, scales = "free", ncol = 2) +
    scale_x_reordered() +
    labs(x = NULL, y = "Beta") +
    theme_minimal()
  
  ggsave(filename = file.path(output_path, "topic_model_visualization.png"), plot = plot, width = 10, height = 6)
}



# Function: Visualize Common Words
visualize_common_words <- function(corpus, output_path, top_n = 10) {
  dtm <- DocumentTermMatrix(corpus)
  term_freq <- colSums(as.matrix(dtm))
  term_freq_sorted <- sort(term_freq, decreasing = TRUE)
  common_words <- head(term_freq_sorted, n = top_n)
  
  common_words_df <- data.frame(
    Word = names(common_words),
    Frequency = as.numeric(common_words),
    stringsAsFactors = FALSE
  )
  
  plot <- ggplot(common_words_df, aes(x = reorder(Word, -Frequency), y = Frequency)) +
    geom_bar(stat = "identity", fill = "skyblue") +
    labs(title = "Top Common Words", x = "Word", y = "Frequency") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(filename = file.path(output_path, "common_words_visualization.png"), plot = plot, width = 8, height = 5)
  print("Common words visualization saved.")
}

# Function: Package the Project
package_project <- function(project_path) {
  if (!dir.exists(project_path)) {
    stop("Project directory does not exist. Please ensure it is created and populated.")
  }
  
  zip::zip(
    zipfile = paste0(project_path, ".zip"),
    files = list.files(project_path, full.names = TRUE, recursive = TRUE)
  )
  
  print(paste("Project zipped at:", paste0(project_path, ".zip")))
}

# Main Script
run_pipeline <- function(input_file, output_folder, custom_stopwords = c(), num_topics = 5, project_path = "Project") {
  # Create directories if they don't exist
  if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)
  if (!dir.exists(project_path)) dir.create(project_path, recursive = TRUE)
  
  print("Loading text data...")
  text_data <- load_text_data(input_file)
  print("Text data loaded.")
  
  print("Cleaning text data...")
  corpus <- clean_text(text_data, custom_stopwords)
  print("Text data cleaned.")
  
  print("Finding common words...")
  find_common_words(corpus, top_n = 10)
  print("Common word has been found")
  
  
  
  print("Writing descriptive statistics...")
  write_descriptive_stats(corpus, output_folder)
  print("Descriptive statistics written.")
  
  print("Performing topic modeling...")
  lda_model <- perform_topic_modeling(corpus, num_topics)
  print("Topic modeling completed.")
  
  print("Outputting topic models...")
  output_topic_models(lda_model, output_folder)
  print("Topic models saved.")
  
  print("Visualizing topics...")
  visualize_topics(lda_model, output_folder)
  print("Topic visualization saved.")
  
  print("Finding common words and visualizing...")
  visualize_common_words(corpus, output_folder)
  print("Common words visualization completed.")
  
  # Copy files to project_path
  file.copy(list.files(output_folder, full.names = TRUE), project_path, recursive = TRUE)
  file.copy(input_file, project_path)
  
  print("Packaging project...")
  package_project(project_path)
  print("Pipeline completed.")
}

# Example Usage
# Define paths and parameters
input_file <- "C:/Users/Emma Davidson/OneDrive - Edinburgh Napier University/Documents/uni-work/project/genAI_abstracts.csv"  # Update with your actual file path
output_folder <- "output"                         # Path to save outputs
custom_stopwords <- c("example", "stopword")      # Add custom stopwords
num_topics <- 5                                   # Number of topics for LDA
project_path <- "Project"                         # Project folder to package

# Run the pipeline
tryCatch({
  run_pipeline(input_file, output_folder, custom_stopwords, num_topics, project_path)
}, error = function(e) {
  print(paste("Error in pipeline:", e$message))
})


