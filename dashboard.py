import os
import re

import emoji
import joblib
import nltk
import streamlit as st
from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Prefer corpora baked into the image, fall back to the local folder in dev
nltk.data.path.append(os.environ.get("NLTK_DATA", os.path.join(BASE_DIR, "nltk_data")))

RESOURCES = [
    ("stopwords", "corpora/stopwords"),
    ("punkt", "tokenizers/punkt"),
    ("punkt_tab", "tokenizers/punkt_tab"),
    ("wordnet", "corpora/wordnet"),
    ("omw-1.4", "corpora/omw-1.4"),
]


def ensure_nltk_data():
    """Download only the corpora that are missing (no-op inside the Docker image)."""
    for package, path in RESOURCES:
        try:
            nltk.data.find(path)
        except LookupError:
            try:
                nltk.download(package, download_dir=os.environ.get("NLTK_DATA"), quiet=True)
            except Exception:
                pass


ensure_nltk_data()

stop_words = set(stopwords.words("english"))
lemmatizer = WordNetLemmatizer()

# Load saved model and vectorizer
model = joblib.load(os.path.join(BASE_DIR, "src", "sentiment_model.pkl"))
vectorizer = joblib.load(os.path.join(BASE_DIR, "src", "tfidf_vectorizer.pkl"))


# Text cleaning function (same logic used in training)
def clean_tweet(text):
    text = text.lower()
    text = re.sub(r"http\S+|www\S+|https\S+", "", text)
    text = re.sub(r"@\w+", "", text)
    text = re.sub(r"#", "", text)
    text = re.sub(r"[^A-Za-z\s]", "", text)
    tokens = nltk.word_tokenize(text)
    tokens = [word for word in tokens if word not in stop_words and len(word) > 2]
    tokens = [lemmatizer.lemmatize(word) for word in tokens]
    return emoji.demojize(" ".join(tokens))


# Streamlit UI
st.set_page_config(page_title="Sentiment Analyzer", page_icon="💬", layout="centered")

st.title("💬 Twitter Sentiment Analysis App")
st.write("Enter a tweet or sentence below to analyze its sentiment (positive or negative).")

user_input = st.text_area("✍️ Write something here...")

if st.button("Analyze Sentiment"):
    if user_input.strip():
        cleaned_text = clean_tweet(user_input)
        transformed_text = vectorizer.transform([cleaned_text])
        prediction = model.predict(transformed_text)[0]
        sentiment = "😊 Positive" if prediction == 1 else "😠 Negative"
        st.subheader(f"Predicted Sentiment: {sentiment}")
    else:
        st.warning("Please enter some text first.")
