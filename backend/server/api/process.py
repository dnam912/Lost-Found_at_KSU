import os
import sys
from fastapi import APIRouter, Form, UploadFile, File

sys.path.append(
    os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../"))
)
from nlp.spacy_nlp import process_with_spacey


router = APIRouter(prefix="/api", tags=["Process"])


@router.post("/process")
async def process_data(
    status: str = Form(...),
    location: str = Form(...),
    date: str = Form(""),
    estimated_start: str = Form(""),
    estimated_end: str = Form(""),
    category: str = Form(""),
    color: str = Form(""),
    material: str = Form(""),
    text: str = Form(...),
    image: UploadFile | None = File(None)
):

    print(f"Received Form Data - Status: {status}, Location: {location}, Date: {date}")
    print(f"Time Range: {estimated_start} ~ {estimated_end}")
    print(f"Keywords - Category: {category}, Color: {color}, Material: {material}")
    print(f"Received Text: {text}")


    # NLP Processing (Return dictionary)
    parsed_result = process_with_spacey(text)


    # Define whether image file is uploaded
    image_info = None
    if image:
        image_info = {
            "filename": image.filename,
            "content_type": image.content_type
        }

    return {
        "status": "success",

        "form_data": {
            "item_status": status,
            "location": location,
            "date": date,
            "estimated_time": {
                "start": estimated_start,
                "end": estimated_end
            },
            "keywords": {
                "category": category,
                "color": color,
                "material": material
            },
            "received_text": text,
            "attached_image": image_info
        },
        
        "parsed_data": parsed_result
    }
