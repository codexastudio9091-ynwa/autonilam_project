import os
import json
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pypdf import PdfReader
from google import genai
from google.genai import types
from pydantic import BaseModel
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="AutoNILAM Core Engine API")

client = genai.Client()

# Configure CORS cross-origin allowances for Flutter Web environments
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production deployment, pin strictly to your Flutter domain URL
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize the 2026 Google GenAI Production client SDK instance 
# The SDK natively checks for the GEMINI_API_KEY environment variable.
client = genai.Client()

class NilamAnalysisResponse(BaseModel):
    title: str
    author: str
    publisher: str
    isFiction: bool
    ulasan: str

def extract_strategic_chunks(file_path: str) -> str:
    """Extracts first and middle pages to slash API token expenses by 90%."""
    reader = PdfReader(file_path)
    total_pages = len(reader)
    combined_text = ""
    
    # Grab introductory structural sections (Metadata, Preface)
    for i in range(min(3, total_pages)):
        combined_text += reader.pages[i].extract_text() or ""
        
    # Grab contextual core plot points from middle quadrants
    if total_pages > 6:
        midpoint = total_pages // 2
        combined_text += reader.pages[midpoint].extract_text() or ""
        combined_text += reader.pages[midpoint + 1].extract_text() or ""
        
    return combined_text

@app.post("/api/v1/analyze", response_model=NilamAnalysisResponse)
async def process_document_upload(file: UploadFile = File(...)):
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Only standard PDF documents are supported.")
        
    temporary_location = f"cache_{file.filename}"
    
    # Stream binary payload from RAM onto disk space safely
    with open(temporary_location, "wb") as buffer:
        buffer.write(await file.read())
        
    try:
        raw_text_payload = extract_strategic_chunks(temporary_location)
        
        system_execution_prompt = """
        You are an expert Malaysian School Resource Center (Guru Media/PSS) coordinator. 
        Analyze the provided book text extract and perform two tasks:
        1. Extract the Title, Author name, and Publisher.
        2. Write a highly compliant reading summary ('ulasan') tailored for a primary/secondary school NILAM entry.
        
        The 'ulasan' must be written in clear, natural Bahasa Melayu, span exactly 3 to 4 sentences, 
        and explicitly outline the core story theme along with a positive moral value ('nilai murni').
        """
        
        # Dispatch structured query request to Gemini-2.5-Flash
        ai_response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=[system_execution_prompt, raw_text_payload],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=types.Schema(
                    type=types.Type.OBJECT,
                    properties={
                        "title": types.Schema(type=types.Type.STRING),
                        "author": types.Schema(type=types.Type.STRING),
                        "publisher": types.Schema(type=types.Type.STRING),
                        "isFiction": types.Schema(type=types.Type.BOOLEAN),
                        "ulasan": types.Schema(type=types.Type.STRING),
                    },
                    required=["title", "author", "publisher", "isFiction", "ulasan"],
                ),
            ),
        )
        
        # Pass native JSON structures safely back to client request handlers
        return json.loads(ai_response.text)
        
    except Exception as server_error:
        raise HTTPException(status_code=500, detail=str(server_error))
        
    finally:
        # Prevent localized environment pollution by forcing immediate disk cleanup routines
        if os.path.exists(temporary_location):
            os.remove(temporary_location)