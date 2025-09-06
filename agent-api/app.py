# main.py
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import requests, json, subprocess
import os

OLLAMA_BASE_URL = os.getenv("OLLAMA_BASE_URL")

app = FastAPI()

class ChatRequest(BaseModel):
    prompt: str

class ExplainRequest(BaseModel):
    command: str

@app.post("/chat")
def chat(data: ChatRequest):
    """
    This endpoint lets you talk to a chat model.
    You send a prompt, and it streams back the response as plain text.
    It's useful for getting answers or generating text based on your input.
    """
    def generate():
        with requests.post(
            f"{OLLAMA_BASE_URL}/api/generate",
            json={"model": "llama3", "prompt": data.prompt},
            stream=True
        ) as r:
            for line in r.iter_lines():
                if line:
                    try:
                        chunk = json.loads(line.decode("utf-8"))
                        if "response" in chunk:
                            yield chunk["response"]
                    except Exception as e:
                        print("Error parsing:", e)
    return StreamingResponse(generate(), media_type="text/plain")

SAFE_COMMANDS = {
    "df -h": "Check disk usage",
    "uptime": "Show system uptime and load",
    "top -l 1 | head -10": "Snapshot of processes",
    "free -h": "Memory usage",
    "whoami": "Current logged in user"
}

@app.post("/explain")
def explain(data: ExplainRequest):
    """
    This endpoint explains the output of safe system commands.
    You provide a command, and if it's allowed, the system runs it and sends the output to a model.
    The model then explains the output in simple terms.
    """
    commands = [cmd.strip() for cmd in data.command.split("&&")]

    results = []
    for cmd in commands:
        if cmd not in SAFE_COMMANDS:
            results.append(f"❌ Command '{cmd}' is not allowed.")
            continue

        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=5
            )
            output = result.stdout or result.stderr
            print(f"Executed '{cmd}': {output}\n")
        except Exception as e:
            results.append(f"⚠️ Error running '{cmd}': {str(e)}")
            continue

        # Pass each command’s output to LLaMA
        explanation = ""
        with requests.post(
            f"{OLLAMA_BASE_URL}/api/generate",
            json={
                "model": "llama3",
                "prompt": f"Explain this system command output in a concise and short single line:\n\nCommand: {cmd}\n\nOutput:\n{output}"
            },
            stream=True
        ) as r:
            for line in r.iter_lines():
                if line:
                    try:
                        chunk = json.loads(line.decode("utf-8"))
                        if "response" in chunk:
                            explanation += chunk["response"]
                    except:
                        pass

        results.append(f"🔹 {cmd} → {explanation.strip()}")

    return {"explanations": results}

@app.get("/health")
def health():
    """
    This endpoint checks the health of the system.
    It runs a set of predefined commands to check things like disk usage, memory, and system load.
    The results are summarized with a severity level (e.g., Healthy, Warning, or Critical)
    to give you a quick idea of the system's status.
    """
    commands = {
        "uptime": "System load & uptime",
        "df -h": "Disk usage",
        "free -h": "Memory usage",
        "whoami": "Current user"
    }

    results = {}
    explanations = []

    for cmd, desc in commands.items():
        try:
            result = subprocess.run(
                cmd, shell=True, capture_output=True, text=True, timeout=5
            )
            output = result.stdout or result.stderr
        except Exception as e:
            results[cmd] = {"status": "error", "output": str(e)}
            continue

        # Ask LLaMA to summarize + add severity markers
        explanation = ""
        with requests.post(
            f"{OLLAMA_BASE_URL}/api/generate",
            json={
                "model": "llama3",
                "prompt": f"""
                Analyze this system command output for {desc}.
                Add a one-line summary with a severity marker:
                - ✅ Healthy
                - ⚠️ Warning (if moderately high)
                - 🔴 Critical (if very high or dangerous)

                Command: {cmd}
                Output:
                {output}
                """
            },
            stream=True
        ) as r:
            for line in r.iter_lines():
                if line:
                    try:
                        chunk = json.loads(line.decode("utf-8"))
                        if "response" in chunk:
                            explanation += chunk["response"]
                    except:
                        pass

        results[cmd] = {"status": "ok", "output": output}
        explanations.append(f"{cmd} → {explanation.strip()}")

    # Return both raw + summarized
    return {
        "health_report": results,
        "summary": explanations
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)