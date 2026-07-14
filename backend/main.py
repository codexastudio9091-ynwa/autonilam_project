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

app = FastAPI(title="AutoNILAM Production Core Engine API")

# UPDATED: Relaxed CORS requirements to accept requests incoming from the live Flutter Web client
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

client = genai.Client()

class NilamAnalysisResponse(BaseModel):
    title: str
    author: str
    publisher: str
    isFiction: bool
    ulasan: str

def extract_strategic_chunks(file_path: str) -> str:
    reader = PdfReader(file_path)
    total_pages = len(reader)
    combined_text = ""
    
    for i in range(min(3, total_pages)):
        combined_text += reader.pages[i].extract_text() or ""
        
    if total_pages > 6:
        midpoint = total_pages // 2
        combined_text += reader.pages[midpoint].extract_text() or ""
        combined_text += reader.pages[midpoint + 1].extract_text() or ""
        
    return combined_text

@app.post("/api/v1/analyze", response_model=NilamAnalysisResponse)
async def process_document_upload(file: UploadFile = File(...)):
    filename_lower = file.filename.lower()
    content_type = file.content_type.lower() if file.content_type else ""
    
    # 1. Advanced check: Verify by extension OR browser MIME type
    is_pdf = filename_lower.endswith('.pdf') or content_type == 'application/pdf'
    
    is_image = (
        filename_lower.endswith(('.jpg', '.jpeg', '.png', '.webp', '.jfif')) or 
        content_type.startswith('image/')
    )
    
    # If it fails both, print to Render logs for debugging and reject
    if not is_pdf and not is_image:
        print(f"Rejected File: Name='{file.filename}', MIME='{file.content_type}'")
        raise HTTPException(
            status_code=400, 
            detail=f"Unsupported format. Got file type profile: MIME={file.content_type}"
        )
        
    temporary_location = f"cache_{file.filename}"
    file_bytes = await file.read()
    
    with open(temporary_location, "wb") as buffer:
        buffer.write(file_bytes)
        
    try:
        system_execution_prompt = """
        You are an expert Malaysian School Resource Center (Guru Media/PSS) coordinator. 
        Analyze the provided book file attachment asset (which may appear as an extracted text stream or a direct graphical page illustration/cover).
        
        Perform two primary tasks:
        1. Extract the Title, Author name, and Publisher. If the author or publisher details are missing from the page visual layouts, infer them logically or input 'Tidak Dinyatakan'.
        - Set 'isFiction' to true if it is a storybook or novel, and false if it is a textbook, factual, or reference book.
        2. Synthesize a pristine, compliant reading review report summary ('ulasan') tailored for a Malaysian school NILAM entry log.
        
        The 'ulasan' MUST meet these exact specifications:
        - Written in natural, standard Bahasa Melayu.
        - Span exactly 3 to 4 complete sentences.
        - Clearly state the overarching theme/plot along with a constructive moral lesson value ('nilai murni').
        """
        
        contents_payload = [system_execution_prompt]
        
        if is_pdf:
            raw_text = extract_strategic_chunks(temporary_location)
            contents_payload.append(raw_text)
        else:
            # Dynamically determine valid web image MIME type mappings
            target_mime = content_type if content_type.startswith('image/') else "image/jpeg"
            image_part = types.Part.from_bytes(
                data=file_bytes,
                mime_type=target_mime,
            )
            contents_payload.append(image_part)
            
        ai_response = client.models.generate_content(
            model='gemini-2.0-flash',
            contents=contents_payload,
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
        
        return json.loads(ai_response.text)
        
    except Exception as server_error:
        raise HTTPException(status_code=500, detail=str(server_error))
        
    finally:
        if os.path.exists(temporary_location):
            os.remove(temporary_location)