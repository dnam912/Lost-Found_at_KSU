import spacy


# input
'''
text = """
I lost a black leather wallet near the library.
It contains my driver's license and my student ID.
"""


text = """
I think I left my black leather wallet somewhere in the student center yesterday afternoon, probably around 2 or 3 pm. I was sitting near the tables by the Starbucks on the first floor, but I also went to the bookstore before I noticed it was gone. It's a small rectangular wallet, mostly black with a little silver zipper on the side and a few scratches on the back. There's my student ID, driver's license, and two credit cards inside, and the student ID has my name, Nadine Nam, on it. I don't remember the brand, but there's a small white logo on the front that kind of looks like a bird or maybe a check mark.
"""
'''

nlp = spacy.load("en_core_web_sm")


def process_with_spacey(text):

    # ======== ======== spaCy ======== ========
    doc = nlp(text)

    # ======== ======== Tokens ======== ========

    print("\nTOKENS")
    print("-" * 40)

    for token in doc:
        if not token.is_space:
            print(f"{token.text:<12} {token.pos_}")

    # ======== ======== Named Entities ======== ========

    print("\nENTITIES")
    print("-" * 40)

    if doc.ents:
        for entity in doc.ents:
            print(f"{entity.text:<20} {entity.label_}")
    else:
        print("None")



    # ======== ======== Dependencies ======== ========

    print("\nDEPENDENCIES")
    print("-" * 40)

    for sent in doc.sents:
        print(f"\nSentence: {sent.text.strip()}")

        for token in sent:
            if not token.is_space:
                print(
                    f"{token.text:<12} "
                    f"({token.pos_:<6}) "
                    f"--{token.dep_:<10}--> "
                    f"{token.head.text}"
                )



    # ======== ======== Feature Extraction ======== ========

    def extract_features(doc):
        features = {
            "entities": [],
            "nouns": [],
            "adjectives": []
        }

        for ent in doc.ents:
            features["entities"].append({
                "text": ent.text,
                "label": ent.label_
            })

        for token in doc:
            if token.pos_ == "NOUN":
                features["nouns"].append(token.text)

            if token.pos_ == "ADJ":
                features["adjectives"].append(token.text)

        return features

    # Run feature extraction once
    features = extract_features(doc)



    # ======== ======== Extracted Feature Output ======== ========
    print("\nEXTRACTED FEATURES")
    print("-" * 40)
    print("Entities:", features["entities"])
    print("Nouns:", features["nouns"])
    print("Adjectives:", features["adjectives"])


    # Return Data for API responses
    return features


    '''
    print("\nEntities:")
    if features["entities"]:
        for entity in features["entities"]:
            print(f"  - {entity['text']} ({entity['label']})")
    else:
        print("  - None")


    print("\nNouns:")
    for noun in features["nouns"]:
        print(f"  - {noun}")


    print("\nAdjectives:")
    for adjective in features["adjectives"]:
        print(f"  - {adjective}")


    print()
    '''


