# Lost-Found_at_KSU

### Project Structure
```text
.
├── web/
│   └── index.html
├── iOS/
│   └── SwiftUI/
├── backend/
│   └── server/
│       ├── main.py
│       ├── api/
│       ├── cdn/
│       ├── db/
│       └── vector/
└── nlp/
    └── spacy_nlp.py
```



### How to Run a Server
**MacOS / Linux**
```bash
# 1. Activate the virtual environment
source .venv/bin/activate

# 2. Start FastAPI + Uvicorn Server
uvicorn main:app --reload
```

**Windows (Powershell)**
```bash
# 1. Activate the virtual environment
# (Note: If using Git Bash on Windows, run source .venv/Scripts/activate)
.\.venv\Scripts\Activate.ps1

# 2. Start FastAPI + Uvicorn Server
uvicorn main:app --reload
```



### How to Set up a Virtual Environment for Running a Server and spaCy (NLP)
```bash
# 1-1. Check if Python 3.11 or higher is installed
# 1-2. Create a virtual environment at the project root
python -m venv .venv

# 2. Activate the virtual environment
source .venv/bin/activate

# 3. Upgrade pip
python -m pip install --upgrade pip

# 4. Install project dependencies from requirements.txt
pip install -r requirements.txt

# 5. Download required spaCy NLP English model
python -m spacy download en_core_web_sm
```
