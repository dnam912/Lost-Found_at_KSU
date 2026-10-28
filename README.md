# Lost-Found_at_KSU

### Project Structure
```text

├── ios/
│   └── SwiftUI/
├── server/
│   ├── main.py
│   ├── requirements.txt
│   ├── install_venv.sh
│   ├── install_venv.bat
│   ├── static/               # Web interface assets
│   │   ├── index.html, script.js, style.css, admin_gallery.html
│   │   └── account/
│   │       └── login.html, signup.html, verification.html, ...
│   ├── api/                  # API endpoints and route handlers
│   │   ├── auth.py, process.py, json_schema.py, image_caching.py
│   │   └── web_matching.py, mobile_matching.py
│   ├── db/                   # PostgreSQL connection and schema
│   │   ├── database.py, lostfoundschemadb.sql
│   │   └── migrations/
│   │       ├── 001_add_mobileclip_embedding.sql
│   │       └── 002_add_app_auth.sql
│   ├── nlp/                  # Text processing and NLP (spaCy)
│   │   └── spacy_nlp.py
│   ├── vector/               # Vector storage and embedding
│       └── web_embedding.py

```



### How to Set up a Virtual Environment for Running the Lost&Found Project
```bash
# Check if Python 3.11 or higher is installed
# Create a virtual environment inside the server directory
cd server

# Create virtual environment
chmod +x install_venv.sh && ./install_venv.sh   # macOS / Linux
# install_venv.bat    # Windows

# Activate virtual environment
source .venv/bin/activate       # macOS/Linux
# .\.venv\Scripts\Activate.ps1  # Windows PowerShell


# Type a URL into a web browser
https://lost-and-found-ksu.taildfefb3.ts.net/
```