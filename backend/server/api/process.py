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
    text: str = Form(...),
    image: UploadFile | None = File(None)
    ):
    print(f"Received Text: {text}")

    # Return dictionary
    parsed_result = process_with_spacey(text)

    return {
        "status": "success",
        "received_text": text,
        "parsed_data": parsed_result,
    }
