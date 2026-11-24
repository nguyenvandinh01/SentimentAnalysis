import sys
import joblib
import re
import nltk
import emoji

# Ensure local nltk_data is prioritized
nltk.data.path.append('./nltk_data')

from nltk.corpus import stopwords
from nltk.stem import WordNetLemmatizer

# Load model and vectorizer
model = joblib.load('src/sentiment_model.pkl')
vectorizer = joblib.load('src/tfidf_vectorizer.pkl')

stop_words = set(stopwords.words('english'))
lemmatizer = WordNetLemmatizer()

def clean_tweet(text):
    text = text.lower()
    text = re.sub(r"http\S+|www\S+|https\S+", '', text)
    text = re.sub(r'@\w+', '', text)
    text = re.sub(r'#', '', text)
    text = re.sub(r'[^A-Za-z\s]', '', text)
    tokens = nltk.word_tokenize(text)
    tokens = [word for word in tokens if word not in stop_words and len(word) > 2]
    tokens = [lemmatizer.lemmatize(word) for word in tokens]
    text = emoji.demojize(" ".join(tokens))
    return text

def predict_sentiment(text):
    cleaned = clean_tweet(text)
    transformed = vectorizer.transform([cleaned])
    pred = model.predict(transformed)[0]
    return "😊 Positive" if pred == 1 else "😠 Negative"

if __name__ == "__main__":
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
        print(f"Loading test file: {filepath}")
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = [line.strip() for line in f if line.strip()]
        
        pos_count = 0
        neg_count = 0
        for i, text in enumerate(lines, 1):
            res = predict_sentiment(text)
            if "Positive" in res:
                pos_count += 1
            else:
                neg_count += 1
            print(f"[{i:02d}] {res} | {text}")
        
        total = len(lines)
        print("\n" + "=" * 50)
        print(f"SUMMARY FOR {filepath}:")
        print(f"Total Sentences: {total}")
        print(f"Positive: {pos_count} ({pos_count/total*100:.1f}%)")
        print(f"Negative: {neg_count} ({neg_count/total*100:.1f}%)")
        print("=" * 50)
    else:
        test_cases = [
            "I love this product, it is absolutely amazing!",
            "Having a wonderful day with my family and friends!",
            "This is the worst service I have ever experienced. Totally terrible.",
            "I hate when my flight gets delayed for hours, so annoying!",
            "The movie was okay, not great but not terrible either."
        ]

        print("=" * 60)
        print("TESTING SENTIMENT ANALYSIS MODEL (DEFAULT SAMPLES)")
        print("=" * 60)
        for text in test_cases:
            res = predict_sentiment(text)
            print(f"Input : \"{text}\"")
            print(f"Result: {res}\n")
