# AIOps Platform (LAD-style Agent)

Production-grade multi-container AIOps agent:
- **agent-api**: FastAPI service exposing `/chat`, `/explain`, `/health`
- **ollama**: LLM runtime (LLaMA 3)

## Quickstart

```bash
cd aiops-platform
cp .env.example .env    # ensure OLLAMA_BASE_URL=http://ollama:11434
docker compose up -d --build
docker compose exec ollama ollama pull llama3
curl -N -X POST http://localhost:8000/chat -H "Content-Type: application/json" -d '{"prompt":"Hello"}'
