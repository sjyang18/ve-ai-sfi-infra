import streamlit as st
import os
from dotenv import load_dotenv
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.search.documents.models import VectorizableTextQuery
from promptflow.core import Prompty, AzureOpenAIModelConfiguration

# Load environment variables
load_dotenv()

# Environment variables
AZURE_OPENAI_ENDPOINT = os.environ.get("AZURE_OPENAI_ENDPOINT")
AZURE_OPENAI_DEPLOYMENT = os.environ.get("AZURE_OPENAI_CHATGPT_DEPLOYMENT")
AZURE_SEARCH_ENDPOINT = os.environ.get("AZURE_SEARCH_ENDPOINT")
AZURE_SEARCH_INDEX = os.environ.get("AZURE_SEARCH_INDEX")

# Setup Azure credential
credential = DefaultAzureCredential()

# Initialize session state for conversation history
if 'conversation_history' not in st.session_state:
    st.session_state.conversation_history = []

# Path to your prompty file
prompty_file_path = os.path.join(os.path.dirname(__file__), "chat.prompty")

def get_search_client():
    """Create and return an Azure Search client"""
    return SearchClient(
        endpoint=AZURE_SEARCH_ENDPOINT,
        index_name=AZURE_SEARCH_INDEX,
        credential=credential
    )

def search_documents(query):
    """Search for documents in Azure Search"""
    client = get_search_client()
    vector_query = VectorizableTextQuery(text=query, k_nearest_neighbors=50, fields="text_vector")
    results = client.search(search_text=query, vector_queries=[vector_query],
                            select="title, metadata_storage_path, chunk", top=5)
    docs = []
    for doc in results:
        docs.append(doc)
    return docs

def chat_with_ai_using_promptflow(user_input, conversation_history=None, documents=None):
    """Chat with Azure OpenAI using PromptFlow"""
    try:
        # Prepare chat history
        chat_history = [{"role": msg["role"], "content": msg["content"]} for msg in conversation_history] if conversation_history else []

        # Format documents for the prompt if available
        formatted_docs = "\n\n".join([
            f"## Document: {d['title']}\nPath: {d['metadata_storage_path']}\n{d['chunk']}"
            for d in documents
        ]) if documents else ""

        # Prepare model configuration
        model_config = AzureOpenAIModelConfiguration(
            azure_deployment=AZURE_OPENAI_DEPLOYMENT,
            api_version="2025-01-01-preview",
            azure_endpoint=AZURE_OPENAI_ENDPOINT
        )

        # Load the prompty file
        chat_prompty = Prompty.load(
            prompty_file_path,
            model={
                "configuration": model_config,
                "parameters": {
                    "temperature": 0.2
                }
            }
        )

        # Call the prompty
        result = chat_prompty(
            chat_input=user_input,
            chat_history=chat_history,
            documents=formatted_docs
        )

        return result

    except Exception as e:
        st.error(f"Error running PromptFlow: {str(e)}")
        return "I'm sorry, I encountered an error processing your request."

def format_search_results_with_promptflow(query, docs):
    """Process search results using PromptFlow"""
    if not docs:
        return "No results found."
    
    # Create a condensed input for the AI
    formatted_docs = "\n\n".join([
        f"## Document: {d['title']}\nPath: {d['metadata_storage_path']}\n{d['chunk']}"
        for d in docs
    ])
    
    # Use the chat_with_ai_using_promptflow function but with a different intent
    search_query = f"Please summarize information about: {query}"
    result = chat_with_ai_using_promptflow(search_query, [], docs)
    
    return result

# App title and description
st.title("🔍 AI Document Search & Chat")
st.markdown("Welcome! This application helps you search documents and get answers to your queries.")

# Chat-like interaction
st.subheader("Chat with the AI")

# Display conversation history
for message in st.session_state.conversation_history:
    if message["role"] == "user":
        with st.chat_message("user"):
            st.markdown(message["content"])
    else:
        with st.chat_message("assistant"):
            st.markdown(message["content"])

# User input with chat_input (submits on Enter key)
user_input = st.chat_input("Ask something...")
if user_input:
    # Add user input to conversation history
    st.session_state.conversation_history.append({"role": "user", "content": user_input})

    # Process the query
    with st.spinner('Processing...'):
        docs = search_documents(user_input)
        if docs:
            formatted_results = format_search_results_with_promptflow(user_input, docs)
            st.session_state.conversation_history.append({"role": "assistant", "content": formatted_results})
        else:
            st.session_state.conversation_history.append({"role": "assistant", "content": "No results found."})

    st.rerun()
