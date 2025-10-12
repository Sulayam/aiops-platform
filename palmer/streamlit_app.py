import os
import requests
import streamlit as st
import pandas as pd
from datetime import datetime

# API config
API_URL = os.getenv("API_URL", "http://palmer.local/api")

# Page setup
st.set_page_config(page_title="Palmer Penguins — AI Classifier", page_icon="🐧", layout="wide")

# ---- GPT-style header ----
st.markdown("""
    <div style='text-align:center;'>
        <h1 style='font-size:2.2em; font-weight:600;'>🐧 Palmer Penguins — AI Classifier</h1>
        <p style='color:#666;'>FastAPI × Streamlit × PostgreSQL × Kubernetes</p>
        <hr style='border:0.5px solid #eee;'>
    </div>
""", unsafe_allow_html=True)

# ---- Prediction form ----
st.markdown("### ✳️ Make a Prediction")
with st.form("penguin_form"):
    col1, col2, col3 = st.columns(3)
    bl = col1.number_input("Bill Length (mm)", 30.0, 60.0, 40.0)
    bd = col2.number_input("Bill Depth (mm)", 13.0, 22.0, 18.0)
    fl = col3.number_input("Flipper Length (mm)", 170.0, 235.0, 190.0)
    bm = col1.number_input("Body Mass (g)", 2500.0, 6500.0, 3700.0)
    sex = col2.selectbox("Sex", ["male", "female"])
    island = col3.selectbox("Island", ["Biscoe", "Dream", "Torgersen"])
    submitted = st.form_submit_button("💡 Predict", use_container_width=True)

if submitted:
    with st.spinner("Predicting..."):
        r = requests.post(f"{API_URL}/predict", json={
            "bill_length_mm": bl,
            "bill_depth_mm": bd,
            "flipper_length_mm": fl,
            "body_mass_g": bm,
            "sex": sex,
            "island": island
        })
        if r.status_code == 200:
            out = r.json()
            st.success(f"### 🐧 Prediction: **{out['prediction']}**")
            st.caption("Confidence probabilities:")
            st.json({"classes": out["classes"], "proba": out["proba"]})
        else:
            st.error(f"Error: {r.text}")

# ---- Past Predictions ----
st.markdown("### 🕓 Recent Predictions")

try:
    resp = requests.get(f"{API_URL}/predictions?limit=10")
    if resp.status_code == 200:
        data = resp.json().get("data", [])
        if data:
            df = pd.DataFrame(data)
            df["created_at"] = pd.to_datetime(df["created_at"])
            df = df.rename(columns={
                "bill_length_mm": "Bill L.",
                "bill_depth_mm": "Bill D.",
                "flipper_length_mm": "Flipper L.",
                "body_mass_g": "Mass (g)",
                "sex": "Sex",
                "island": "Island",
                "predicted": "Predicted",
                "created_at": "Timestamp"
            })
            st.dataframe(
                df[["Timestamp","Predicted","Sex","Island","Bill L.","Bill D.","Flipper L.","Mass (g)"]],
                use_container_width=True,
                hide_index=True
            )
        else:
            st.info("No predictions logged yet.")
    else:
        st.warning("Could not fetch history from API.")
except Exception as e:
    st.error(str(e))

# ---- Footer ----
st.markdown("""
<hr style='border:0.5px solid #eee;'>
<p style='text-align:center;color:#888;font-size:0.9em;'>
Built with ❤️ using FastAPI · Streamlit · PostgreSQL · Kubernetes
</p>
""", unsafe_allow_html=True)
