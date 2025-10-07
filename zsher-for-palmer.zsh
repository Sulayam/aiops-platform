set -euo pipefail

# root
mkdir -p palmer/{app,k8s,.vscode}
cd palmer

# .gitignore
cat > .gitignore <<'EOF'
.venv/
__pycache__/
*.pyc
*.pyo
*.pyd
*.DS_Store
.env
.env.*
dist/
build/
.eggs/
.cache/
.ipynb_checkpoints/
*.egg-info/
model/
EOF

# .dockerignore
cat > .dockerignore <<'EOF'
.venv
.git
__pycache__
*.pyc
*.pyo
*.pyd
*.DS_Store
.env
.env.*
dist
build
.eggs
.cache
.ipynb_checkpoints
*.egg-info
EOF

# VS Code settings
mkdir -p .vscode
cat > .vscode/settings.json <<'EOF'
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
  "python.analysis.typeCheckingMode": "basic",
  "editor.formatOnSave": true
}
EOF

# requirements
cat > requirements.txt <<'EOF'
fastapi
uvicorn
pydantic
pandas
scikit-learn
joblib
numpy
streamlit
requests
EOF

# training script
cat > train.py <<'EOF'
import joblib, pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score

URL = "https://raw.githubusercontent.com/allisonhorst/palmerpenguins/main/inst/extdata/penguins.csv"
df = pd.read_csv(URL)

cols = ["bill_length_mm","bill_depth_mm","flipper_length_mm","body_mass_g","sex","island","species"]
df = df.dropna(subset=cols)
X = df[["bill_length_mm","bill_depth_mm","flipper_length_mm","body_mass_g","sex","island"]]
y = df["species"]

num = ["bill_length_mm","bill_depth_mm","flipper_length_mm","body_mass_g"]
cat = ["sex","island"]

pre = ColumnTransformer([
    ("num", StandardScaler(), num),
    ("cat", OneHotEncoder(handle_unknown="ignore"), cat)
])

clf = LogisticRegression(max_iter=500)
pipe = Pipeline([("pre", pre), ("clf", clf)])

Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.2, stratify=y, random_state=42)
pipe.fit(Xtr, ytr)
pred = pipe.predict(Xte)
print("accuracy:", round(accuracy_score(yte, pred), 3))

# persist into app/ so the API image can COPY it
joblib.dump(pipe, "app/model.pkl")
EOF

# FastAPI app
mkdir -p app
cat > app/__init__.py <<'EOF'
# intentional
EOF

cat > app/main.py <<'EOF'
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
EOF

# Streamlit UI
cat > streamlit_app.py <<'EOF'
import os, requests, streamlit as st

API_URL = os.getenv("API_URL", "http://127.0.0.1:8000")

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
EOF

# Dockerfiles
cat > Dockerfile.api <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
EXPOSE 8000
CMD ["uvicorn","app.main:app","--host","0.0.0.0","--port","8000"]
EOF

cat > Dockerfile.ui <<'EOF'
FROM python:3.11-slim
WORKDIR /ui
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY streamlit_app.py .
EXPOSE 8501
ENV STREAMLIT_SERVER_HEADLESS=true
CMD ["streamlit","run","streamlit_app.py","--server.port","8501","--server.address","0.0.0.0"]
EOF

# K8s manifests (namespace: palmer)
mkdir -p k8s
cat > k8s/namespace.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: palmer
EOF

cat > k8s/api-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: palmer-api
  namespace: palmer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: palmer-api
  template:
    metadata:
      labels:
        app: palmer-api
    spec:
      containers:
      - name: api
        image: palmer-api:0.1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8000
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
        readinessProbe:
          httpGet:
            path: /
            port: 8000
          initialDelaySeconds: 2
        livenessProbe:
          httpGet:
            path: /
            port: 8000
          initialDelaySeconds: 5
EOF

cat > k8s/api-svc.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: palmer-api
  namespace: palmer
spec:
  selector:
    app: palmer-api
  ports:
  - name: http
    port: 8000
    targetPort: 8000
  type: ClusterIP
EOF

cat > k8s/ui-deploy.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: palmer-ui
  namespace: palmer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: palmer-ui
  template:
    metadata:
      labels:
        app: palmer-ui
    spec:
      containers:
      - name: ui
        image: palmer-ui:0.1
        imagePullPolicy: IfNotPresent
        env:
        - name: API_URL
          value: "http://palmer-api:8000"
        ports:
        - containerPort: 8501
        resources:
          requests:
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
EOF

cat > k8s/ui-svc.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: palmer-ui
  namespace: palmer
spec:
  selector:
    app: palmer-ui
  ports:
  - name: http
    port: 80
    targetPort: 8501
  type: ClusterIP
EOF

cat > k8s/ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: palmer
  namespace: palmer
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - host: palmer.local
    http:
      paths:
      - path: /ui(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: palmer-ui
            port:
              number: 80
      - path: /api(/|$)(.*)
        pathType: Prefix
        backend:
          service:
            name: palmer-api
            port:
              number: 8000
EOF

cat > k8s/hpa.yaml <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: palmer-api-hpa
  namespace: palmer
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: palmer-api
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
EOF

cat > k8s/rbac.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
  namespace: palmer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-config
  namespace: palmer
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-read-config
  namespace: palmer
subjects:
- kind: ServiceAccount
  name: app
  namespace: palmer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: read-config
EOF

# README
cat > README.md <<'EOF'
# Palmer Penguins MLOps project