import os
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pypdf import PdfReader
from google import genai
from google.genai import types
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="AutoNILAM Simplified Text Engine")

# Open up open global access parameters for our local web dashboard instance
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

client = genai.Client()

def extract_strategic_chunks(file_path: str) -> str:
    """Extracts first few pages to pass context text safely."""
    reader = PdfReader(file_path)
    combined_text = ""
    for i in range(min(4, len(reader))):
        combined_text += reader.pages[i].extract_text() or ""
    return combined_text

@app.post("/api/v1/analyze")
async def analyze_book_material(file: UploadFile = File(...)):
    filename_lower = file.filename.lower()
    
    is_pdf = filename_lower.endswith('.pdf')
    is_image = filename_lower.endswith(('.jpg', '.jpeg', '.png'))
    
    if not is_pdf and not is_image:
        raise HTTPException(status_code=400, detail="Invalid extension. Please provide a PDF or Image layout.")
        
    temporary_location = f"cache_{file.filename}"
    file_bytes = await file.read()
    
    with open(temporary_location, "wb") as buffer:
        buffer.write(file_bytes)
        
    try:
        # Prompt explicitly optimized to instruct plain text formatting
        system_execution_prompt = """
        You are an expert Malaysian School Resource Center teacher. Look at this book file.
        Extract and summarize its data into a clean text profile matching this exact format layout:
        
        TAJUK BUKU: [Insert Title Here]
        PENULIS: [Insert Author Here]
        PENERBIT: [Insert Publisher Here]
        KATEGORI: [Fiksyen / Bukan Fiksyen]
        
        RUMUSAN NILAM (3-4 Sentences in Bahasa Melayu with moral value):
        [Insert clean 3-4 sentence reading ulasan summary here]
        """
        
        contents_payload = [system_execution_prompt]
        
        if is_pdf:
            raw_text = extract_strategic_chunks(temporary_location)
            contents_payload.append(raw_text)
        else:
            mime_type = "image/png" if filename_lower.endswith('.png') else "image/jpeg"
            image_part = types.Part.from_bytes(data=file_bytes, mime_type=mime_type)
            contents_payload.append(image_part)
            
        # Simplified execution without strict JSON constraints or schema blocks
        ai_response = client.models.generate_content(
            model='gemini-2.0-flash',
            contents=contents_payload
        )
        
        # Plain string payload returned directly 
        return {"result": ai_response.text}
        
    except Exception as server_error:
        raise HTTPException(status_code=500, detail=str(server_error))
        
    finally:
        if os.path.exists(temporary_location):
            os.remove(temporary_location)