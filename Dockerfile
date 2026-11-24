
# Python runtime
FROM python:3.11-slim

# Working directory
WORKDIR /app

# Copy and install dependencies
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Copy source code and trained models
COPY dashboard.py .
COPY src/ ./src/

# Cloud Run port
ENV PORT=8080

EXPOSE 8080

# Start Streamlit
CMD ["sh", "-c", "streamlit run dashboard.py --server.address=0.0.0.0 --server.port=${PORT} --server.headless=true"]
