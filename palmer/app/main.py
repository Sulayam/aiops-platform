from fastapi import FastAPI
from pydantic import BaseModel
import joblib, pandas as pd
import os
import psycopg2

from fastapi.middleware.cors import CORSMiddleware

# Database configuration
DB_HOST = os.getenv("DB_HOST", "postgres")
DB_NAME = os.getenv("POSTGRES_DB", "palmerdb")
DB_USER = os.getenv("POSTGRES_USER", "palmeruser")
DB_PASS = os.getenv("POSTGRES_PASSWORD", "palmerpass")

# Establish database connection
conn = psycopg2.connect(
    host=DB_HOST, dbname=DB_NAME, user=DB_USER, password=DB_PASS
)
cur = conn.cursor()

app = FastAPI()

# Load the model
MODEL_PATH = "/app/storage/model.pkl"
if os.path.exists(MODEL_PATH):
    model = joblib.load(MODEL_PATH)
    print(f"✅ Loaded model from {MODEL_PATH}")
else:
    raise FileNotFoundError(f"❌ Model not found at {MODEL_PATH}")
CLASSES = model.named_steps["clf"].classes_.tolist()

class PenguinData(BaseModel):
    bill_length_mm: float
    bill_depth_mm: float
    flipper_length_mm: float
    body_mass_g: float
    sex: str       # "male" | "female"
    island: str    # "Biscoe" | "Dream" | "Torgersen"

@app.on_event("startup")
def create_table():
    """
    Create the predictions table if it doesn't already exist.
    """
    cur.execute("""
    CREATE TABLE IF NOT EXISTS predictions (
        id SERIAL PRIMARY KEY,
        bill_length_mm FLOAT,
        bill_depth_mm FLOAT,
        flipper_length_mm FLOAT,
        body_mass_g FLOAT,
        sex TEXT,
        island TEXT,
        predicted TEXT,
        created_at TIMESTAMP DEFAULT NOW()
    )
    """)
    conn.commit()

@app.get("/")
def health():
    """
    Health check endpoint.
    """
    return {"status": "ok"}

@app.post("/predict")
def predict(data: PenguinData):
    """
    Predict the species of a penguin based on its features.
    Save the prediction to the database.
    """
    try:
        # Prepare input data for the model
        X = pd.DataFrame([data.model_dump()], columns=[
            "bill_length_mm", "bill_depth_mm", "flipper_length_mm", "body_mass_g", "sex", "island"
        ])
        y = model.predict(X)[0]
        proba = model.predict_proba(X)[0].tolist()

        # Save the prediction to the database
        cur.execute(
            """
            INSERT INTO predictions (bill_length_mm, bill_depth_mm, flipper_length_mm,
                                      body_mass_g, sex, island, predicted, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
            """,
            (data.bill_length_mm, data.bill_depth_mm, data.flipper_length_mm,
             data.body_mass_g, data.sex, data.island, y)
        )
        conn.commit()

        return {"prediction": y, "classes": CLASSES, "proba": proba}
    except Exception as e:
        return {"error": str(e)}

# Allow Streamlit to call this API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # or specify ["http://palmer.local"]
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/predictions")
def get_predictions(limit: int = 10):
    """
    Return the most recent predictions.
    """
    try:
        cur.execute("""
            SELECT id, bill_length_mm, bill_depth_mm, flipper_length_mm, body_mass_g,
                   sex, island, predicted, created_at
            FROM predictions
            ORDER BY created_at DESC
            LIMIT %s
        """, (limit,))
        rows = cur.fetchall()
        cols = [desc[0] for desc in cur.description]
        results = [dict(zip(cols, row)) for row in rows]
        return {"count": len(results), "data": results}
    except Exception as e:
        return {"error": str(e)}
