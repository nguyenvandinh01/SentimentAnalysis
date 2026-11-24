# Python runtime
FROM python:3.11-slim

# Avoid pycache and set a fixed port (AWS App Runner / Cloud Run friendly)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    NLTK_DATA=/app/nltk_data \
    PORT=8080

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Download NLTK corpora at build time so the running container needs no network
RUN python -c "import nltk; [nltk.download(p, download_dir='/app/nltk_data', quiet=True) for p in ['stopwords', 'punkt', 'punkt_tab', 'wordnet', 'omw-1.4']]"

# Copy source code and trained models
COPY dashboard.py .
COPY src/ ./src/

EXPOSE 8080

# Start Streamlit (App Runner forwards traffic to $PORT)
CMD ["sh", "-c", "streamlit run dashboard.py --server.address=0.0.0.0 --server.port=${PORT} --server.headless=true"]
