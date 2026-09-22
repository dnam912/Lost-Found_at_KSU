from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from spacy_nlp import process_with_spacey

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class TextRequest(BaseModel):
    text: str


@app.post("/api/process")
async def process_data(request: TextRequest):

    print(f"Received Text: {request.text}")

    process_with_spacey(request.text)

    return {
        "status": "success",
        "received_text": request.text
    }


''' TEST
@app.get("/api/helloworld")
async def say_hello(text: str):

    print(f"SAY HELLO ENDPOINT REACHED!!!!!")

    return {
        "status": "success",
        "received_text": text
    }
'''





