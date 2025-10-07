import os
import requests
import streamlit as st

API_URL = os.getenv("API_URL", "http://palmer.local/api")

st.title("Palmer Penguins — Species Classifier")

with st.form("penguin"):
    bl = st.number_input("bill_length_mm", 30.0, 60.0, 40.0)
    bd = st.number_input("bill_depth_mm", 13.0, 22.0, 18.0)
    fl = st.number_input("flipper_length_mm", 170.0, 235.0, 190.0)
    bm = st.number_input("body_mass_g", 2500.0, 6500.0, 3700.0)
    sex = st.selectbox("sex", ["male","female"])
    island = st.selectbox("island", ["Biscoe","Dream","Torgersen"])
    submitted = st.form_submit_button("Predict")

if submitted:
    r = requests.post(f"{API_URL}/predict", json={
        "bill_length_mm": bl, "bill_depth_mm": bd, "flipper_length_mm": fl,
        "body_mass_g": bm, "sex": sex, "island": island
    }, timeout=10)
    r.raise_for_status()
    out = r.json()
    st.subheader(f"Prediction: {out['prediction']}")
    st.write({"classes": out["classes"], "proba": out["proba"]})
