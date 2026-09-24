# Lost-Found_at_KSU

Folders:
- web
- iOS
- nlp
- backend


# 1. Create a virtual environment at the project root
python -m venv .venv

# 2. Activate the virtual environment
source .venv/bin/activate

# 3. Upgrade pip
python -m pip install --upgrade pip

# 4. Install project dependencies from requirements.txt
pip install -r requirements.txt

# 5. Download required spaCy NLP English model
python -m spacy download en_core_web_sm