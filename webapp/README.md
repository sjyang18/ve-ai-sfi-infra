# Streamlit AI Document Search & Chat

A Streamlit application for searching documents and chatting with an AI assistant using Azure OpenAI and Azure Search services.

## Setup Instructions

1. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

2. **Environment Variables**:
   The application uses environment variables configured in the `.env` file:
   
   - `AZURE_OPENAI_ENDPOINT`: Your Azure OpenAI service endpoint
   - `AZURE_OPENAI_CHATGPT_DEPLOYMENT`: Your GPT model deployment name
   - `AZURE_SEARCH_ENDPOINT`: Your Azure Search service endpoint
   - `AZURE_SEARCH_INDEX`: Your Azure Search index name

3. **Azure Authentication**:
   Make sure you're logged in with the Azure CLI or have the appropriate credentials set up for DefaultAzureCredential:
   ```bash
   az login
   ```

## Running the Application

To run the Streamlit application:

```bash
streamlit run app.py
```

This will start the application and open it in your default web browser. By default, Streamlit runs on port 8501, so you can access it at http://localhost:8501.

## Features

- **Document Search**: Search through documents indexed in Azure Search
- **AI Chat**: Interact with an AI assistant powered by Azure OpenAI
- **AI-Formatted Results**: Get search results formatted and summarized by AI

## Application Structure

- `app.py`: Main Streamlit application
- `.env`: Environment variables
- `requirements.txt`: Required Python packages
