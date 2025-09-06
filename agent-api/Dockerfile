# Python base (small)
FROM python:3.11-slim

# System deps (optional but handy for debugging/health)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl procps && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Leverage layer caching for deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Add app code
COPY . .

# Create a writable logs dir
RUN mkdir -p /app/logs

EXPOSE 8000
ENV PYTHONUNBUFFERED=1

# Start API
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]