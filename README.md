# 💬 Twitter Sentiment Analysis App

A complete **end-to-end NLP project** that classifies tweets as **Positive** or **Negative** using the [Sentiment140 Dataset](https://www.kaggle.com/datasets/kazanova/sentiment140).  
This project combines **Natural Language Processing**, **Machine Learning**, and **MLOps** — from data cleaning to model deployment.

---

## 🚀 Features

✅ Text Preprocessing (cleaning, tokenization, lemmatization)  
✅ TF-IDF Vectorization for feature extraction  
✅ Multiple ML models with cross-validation & hyperparameter tuning  
✅ Streamlit web app for real-time sentiment prediction  
✅ Model saving & reusability with `joblib`  
✅ Fully Dockerized for consistent deployment  
✅ GitHub Actions CI Workflow for automated testing & build  
✅ Kubernetes/Manifest ready for cloud deployment *(optional)*  

---

## 🧩 Project Structure
```
├── .github
    └── workflows
    │   └── sentimentlsis.yml
├── Docker-compose.yml
├── Dockerfile
├── dashboard.py
├── manifest.yml
├── requirements.txt
└── src
    ├── preprep.ipynb
    ├── sentiment_model.pkl
    └── tfidf_vectorizer.pkl
```

---

## 🧠 Tech Stack

| Category | Tools / Libraries |
|-----------|------------------|
| **Language** | Python |
| **Data Handling** | Pandas, NumPy |
| **NLP** | NLTK, Regex, Emoji |
| **Feature Extraction** | TF-IDF (sklearn) |
| **Modeling** | Logistic Regression, SVM, Random Forest |
| **App Framework** | Streamlit |
| **Model Persistence** | Joblib |
| **Containerization** | Docker |
| **Automation** | GitHub Actions |
| **Deployment** | Streamlit Cloud / Render / Kubernetes |

---

## 🧹 Data Preprocessing

- Lowercasing text  
- Removing URLs, mentions, hashtags, and punctuation  
- Tokenization using **nltk**  
- Stopword removal  
- Lemmatization (`WordNetLemmatizer`)  
- Emoji handling (`emoji.demojize`)  

This ensures the model sees only meaningful words.

---

## 🧮 Feature Engineering — TF-IDF

**Why TF-IDF?**  
It represents each tweet as a numerical vector based on **word importance**.

\[
TFIDF(w) = TF(w) \times \log\left(\frac{N}{df(w)}\right)
\]

Used `TfidfVectorizer(max_features=5000, ngram_range=(1,2))` for best balance between accuracy and speed.

---

## 🤖 Model Training

| Model | Description | Accuracy (CV) |
|--------|--------------|---------------|
| Logistic Regression | Simple & effective for text data | ✅ Best |
| SVM | Handles high-dimensional data | Good |
| Random Forest | Captures non-linear patterns | Moderate |

Performed:
- **5-Fold Cross-Validation**
- **GridSearchCV** for hyperparameter tuning  
- **Evaluation Metrics:** Accuracy, Precision, Recall, F1-score

---

## 💾 Model Saving

Used `joblib` to persist model and TF-IDF vectorizer:
```python
joblib.dump(model, 'sentiment_model.pkl')
joblib.dump(tfidf, 'tfidf_vectorizer.pkl')
```
## Streamlit Web App

<h3>Simple, interactive web app for real-time predictions.</h3>
<h3>Run locally:</h3>
streamlit run app.py


<ol> <h3>App Flow:</h3>
<li>Input tweet text 📝</li>
<li>Clean & preprocess</li>
<li>Convert text → TF-IDF vector</li>
<li>Predict sentiment using model</li>
<li>Display result (😊 Positive / 😠 Negative)</li>  </ol>

<hr>
## 🐳 Docker Integration
<pre>
docker build -t sentiment-app .
docker run -p 8501:8501 sentiment-app
</pre>
<hr>
<ul>
<h1>📊 Results</h1>
<li>Logistic Regression achieved ~85% accuracy on validation data</li>
<li>Clean UI for sentiment prediction</li>
<li>Fully automated CI/CD pipeline with Docker integration</li>
</ul>
<hr>
<ul>
<h1>Key Takeaways</h1>
  <li>Built a complete ML workflow: from preprocessing → training → deployment</li>
  <li>Learned to ensure preprocessing consistency between training & inference</li>
  <li>Containerized the app for reproducibility</li>
  <li>Automated CI/CD with GitHub Actions</li>
  <li>Gained experience with MLOps fundamentals</li>
</ul>
<hr>
<h1>Setup Instructions</h1>
<pre>
## Clone repo
git clone https://github.com/<your-username>/sentiment-analysis.git
cd sentiment-analysis
# Install dependencies
pip install -r requirements.txt
# Run Streamlit app
streamlit run app.py
</pre>
<h3>or run in Docker:</h3>
<pre>docker-compose up --build</pre>
<hr>
## ☁️ Deploy to AWS App Runner

The app is deployed as a Docker image on **AWS App Runner** (region `ap-southeast-2`).

Prerequisites:
- AWS CLI installed and configured (`aws configure`) with permissions for ECR, IAM, CodeBuild and App Runner.
- The changes pushed to the public GitHub repository.

Deploy / update with one command:

```powershell
.\deploy\deploy.ps1 -Region ap-southeast-2
```

The script creates/reuses:
- an **ECR** repository (`sentiment-analysis`),
- IAM roles for **CodeBuild** and **App Runner**,
- a **CodeBuild** project that builds `Dockerfile` from GitHub and pushes the image,
- an **App Runner** service listening on port `8080` with health check `/_stcore/health`.

It prints the public HTTPS URL of the running service when done.

<hr>
<h1>Author</h1>
<h2>Sameer Chauhan</h2>
<h5>MLOps & Machine Learning Engineer</h5>
<h5>💼 Passionate about bridging ML with real-world deployment through Docker, CI/CD, and automation.</h5>
