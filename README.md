# 🚀 AI-Ops Platform (Work in Progress)

The **AI-Ops Platform** is an **autonomous AI engineer for infrastructure operations**.
It combines **LLMs** (via [Ollama](https://ollama.com)) with **FastAPI microservices** and modern DevOps practices to deliver:

* **Chat-based assistance** (`/chat`)
* **Command output interpretation** (`/explain`)
* **System health analysis** (`/health`)

This project is being built with **production-grade DevOps standards** in mind, intended for companies who want a reliable, extensible **AI-Ops assistant** for their infrastructure teams.

---

## ✅ Current Progress

* [x] Project structured into multi-container setup (`agent-api` + `ollama`)
* [x] Dockerfile + `.dockerignore` + volume mounts for persistence
* [x] Docker Compose with health checks and env-based configuration
* [x] Environment variable injection via `.env` (`OLLAMA_BASE_URL`)
* [x] FastAPI app with three endpoints:

  * `/chat` → interactive LLM responses
  * `/explain` → explains safe system commands
  * `/health` → health checks + severity summaries
* [x] Local testing with `curl` → all endpoints verified

---

## 🔜 Roadmap (Work Remaining)

* [ ] Push versioned images (`v1.0.0`) to Docker Hub
* [ ] Deploy stack to AWS EC2 with Docker Compose
* [ ] Add CI/CD pipeline (GitHub Actions)
* [ ] Infrastructure as Code (Terraform) for reproducible cloud setup
* [ ] Secure API with JWT authentication + RBAC
* [ ] Add monitoring/logging stack (Prometheus, Grafana, ELK)
* [ ] Kubernetes deployment for scalability (beyond single EC2)
* [ ] Documentation + API usage guides

---

## 📂 Project Structure

```
aiops-platform/
├── docker-compose.yaml       # Multi-service orchestration
├── .env.example              # Example env vars
├── .dockerignore             # Ignore unnecessary files during build
└── agent-api/                # FastAPI microservice
    ├── app.py                 # FastAPI app (chat, explain, health)
    ├── requirements.txt       # Python dependencies
    ├── Dockerfile             # Agent service container definition
    └── logs/                  # Mounted log output
```

---

## 🛠️ Getting Started (Local Dev)

1. Clone this repo:

   ```bash
   git clone https://github.com/Sulayam/aiops-platform.git
   cd aiops-platform
   ```

2. Copy the env file:

   ```bash
   cp .env.example .env
   ```

   Edit `.env`:

   ```
   OLLAMA_BASE_URL=http://ollama:11434
   ```

3. Build & start services:

   ```bash
   docker compose up -d --build
   ```

4. Pull model inside `ollama` container:

   ```bash
   docker compose exec ollama ollama pull llama3
   ```

5. Test endpoints:

   ```bash
   curl -X POST http://localhost:8000/chat \
     -H "Content-Type: application/json" \
     -d '{"prompt":"Say hello"}'
   ```

---

## ⚠️ Status

This project is **Work in Progress (WIP)**.
**Milestone 1 (Local multi-container stack)** is complete.
Next milestone: **Push images to Docker Hub & deploy on AWS EC2**.

---
