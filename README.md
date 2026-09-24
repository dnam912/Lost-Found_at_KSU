# Lost-Found_at_KSU

Folders:
[ web ]
    index.html
[ iOS ]
    SwiftUI
[ backend ]
    [ server ]
        main.py
        [ api ]
        [ cdn ]
        [ db ]
        [ vector ]
[ nlp ]
    spacy_nlp.py



// How to Set up a Virtual Environment
// 1. Create a virtual environment at the project root
python -m venv .venv

// 2. Activate the virtual environment
source .venv/bin/activate

// 3. Upgrade pip
python -m pip install --upgrade pip

// 4. Install project dependencies from requirements.txt
pip install -r requirements.txt

// 5. Download required spaCy NLP English model
python -m spacy download en_core_web_sm