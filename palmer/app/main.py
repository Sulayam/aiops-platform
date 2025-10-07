from fastapi import FastAPI
from pydantic import BaseModel
import joblib, pandas as pd

app = FastAPI()
model = joblib.load("app/model.pkl")
# classes from the trained classifier inside the pipeline
CLASSES = model.named_steps["clf"].classes_.tolist()

class PenguinIn(BaseModel):
    bill_length_mm: float
    bill_depth_mm: float
    flipper_length_mm: float
    body_mass_g: float
    sex: str       # "male" | "female"
    island: str    # "Biscoe" | "Dream" | "Torgersen"

@app.get("/")
def health():
    return {"status": "ok"}

@app.post("/predict")
def predict(x: PenguinIn):
    try:
        data = x.model_dump()   # pydantic v2
    except AttributeError:
        data = x.dict()         # pydantic v1 fallback
    X = pd.DataFrame([data], columns=[
        "bill_length_mm","bill_depth_mm","flipper_length_mm","body_mass_g","sex","island"
    ])
    y = model.predict(X)[0]
    proba = model.predict_proba(X)[0].tolist()
    return {"prediction": y, "classes": CLASSES, "proba": proba}