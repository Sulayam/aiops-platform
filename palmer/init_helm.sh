#!/usr/bin/env bash
set -euo pipefail

CHART="palmer-helm"        # existing chart folder
NS="palmer"                # default namespace
API_IMG="palmer-api:0.6"   # current tags
UI_IMG="palmer-ui:0.2"

# ────────────────────────────────────────────────
echo "▶︎ Resetting Helm chart…"
rm -rf "$CHART"
helm create "$CHART"          # scaffold again
rm -rf "$CHART/templates"/* "$CHART/charts"/* "$CHART/values.schema.json"

# ────────────────────────────────────────────────
echo "▶︎ Write values.yaml"
cat > "$CHART/values.yaml" <<YAML
namespace: $NS

image:
  api: $API_IMG
  ui:  $UI_IMG
postgres:
  db: palmerdb
  user: palmeruser
  password: palmerpass
replicaCount: 1
YAML

# ────────────────────────────────────────────────
mkdir -p "$CHART/templates"

write() {                           # helper → write a template file
  local f="$CHART/templates/$1"; shift
  printf "%s\n" "$*" > "$f"
}

# 1️⃣ Namespace
write namespace.yaml "
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.namespace }}
"

# 2️⃣ Secret (Postgres creds)
write postgres-secret.yaml "
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: {{ .Values.namespace }}
type: Opaque
stringData:
  POSTGRES_DB: {{ .Values.postgres.db }}
  POSTGRES_USER: {{ .Values.postgres.user }}
  POSTGRES_PASSWORD: {{ .Values.postgres.password }}
"

# 3️⃣ ConfigMap (non-secret envs)
write configmap.yaml "
apiVersion: v1
kind: ConfigMap
metadata:
  name: palmer-config
  namespace: {{ .Values.namespace }}
data:
  API_URL: \"http://palmer-api.{{ .Values.namespace }}.svc.cluster.local:8000\"
  MODEL_PATH: \"/app/storage/model.pkl\"
  DB_HOST: \"postgres\"
  POSTGRES_DB: {{ .Values.postgres.db }}
  POSTGRES_USER: {{ .Values.postgres.user }}
"

# 4️⃣ PVCs
write model-pvc.yaml "
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: palmer-model-pvc
  namespace: {{ .Values.namespace }}
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Mi
  storageClassName: local-path
"
write postgres-pvc.yaml "
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: {{ .Values.namespace }}
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 500Mi
  storageClassName: local-path
"

# 5️⃣ Postgres Deployment / Service
write postgres.yaml "
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: {{ .Values.namespace }}
spec:
  selector:
    matchLabels: { app: postgres }
  template:
    metadata:
      labels: { app: postgres }
    spec:
      containers:
      - name: postgres
        image: postgres:16
        ports: [{ containerPort: 5432 }]
        envFrom:
        - secretRef: { name: postgres-secret }
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
        livenessProbe:
          exec: { command: [\"pg_isready\", \"-U\", \"{{ .Values.postgres.user }}\"] }
          initialDelaySeconds: 30
        readinessProbe:
          exec: { command: [\"pg_isready\", \"-U\", \"{{ .Values.postgres.user }}\"] }
          initialDelaySeconds: 5
      volumes:
      - name: data
        persistentVolumeClaim: { claimName: postgres-pvc }
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: {{ .Values.namespace }}
spec:
  ports: [{ port: 5432, targetPort: 5432 }]
  selector: { app: postgres }
  type: ClusterIP
"

# 6️⃣ API Deployment / Service
write api.yaml "
apiVersion: apps/v1
kind: Deployment
metadata:
  name: palmer-api
  namespace: {{ .Values.namespace }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels: { app: palmer-api }
  template:
    metadata:
      labels: { app: palmer-api }
    spec:
      containers:
      - name: api
        image: {{ .Values.image.api }}
        ports: [{ containerPort: 8000 }]
        envFrom:
        - configMapRef: { name: palmer-config }
        - secretRef:   { name: palmer-secrets }
        volumeMounts:
        - name: model
          mountPath: /app/storage
        resources:
          requests: { cpu: \"50m\", memory: \"64Mi\" }
          limits:   { cpu: \"200m\", memory: \"256Mi\" }
      volumes:
      - name: model
        persistentVolumeClaim: { claimName: palmer-model-pvc }
---
apiVersion: v1
kind: Service
metadata:
  name: palmer-api
  namespace: {{ .Values.namespace }}
spec:
  ports: [{ name: http, port: 8000, targetPort: 8000 }]
  selector: { app: palmer-api }
  type: ClusterIP
"

# 7️⃣ UI Deployment / Service
write ui.yaml "
apiVersion: apps/v1
kind: Deployment
metadata:
  name: palmer-ui
  namespace: {{ .Values.namespace }}
spec:
  replicas: 1
  selector:
    matchLabels: { app: palmer-ui }
  template:
    metadata:
      labels: { app: palmer-ui }
    spec:
      containers:
      - name: ui
        image: {{ .Values.image.ui }}
        ports: [{ containerPort: 8501 }]
        envFrom:
        - configMapRef: { name: palmer-config }
        resources:
          requests: { cpu: \"50m\", memory: \"64Mi\" }
          limits:   { cpu: \"200m\", memory: \"256Mi\" }
---
apiVersion: v1
kind: Service
metadata:
  name: palmer-ui
  namespace: {{ .Values.namespace }}
spec:
  ports: [{ name: http, port: 80, targetPort: 8501 }]
  selector: { app: palmer-ui }
  type: ClusterIP
"

# 8️⃣ Ingress
write ingress.yaml "
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: palmer
  namespace: {{ .Values.namespace }}
  annotations:
    kubernetes.io/ingress.class: \"nginx\"
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
spec:
  rules:
  - host: palmer.local
    http:
      paths:
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: palmer-api
            port: { number: 8000 }
      - path: /()(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: palmer-ui
            port: { number: 80 }
"

# 9️⃣ HPA (disabled by default; enable via values)
write hpa.yaml "
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: palmer-api-hpa
  namespace: {{ .Values.namespace }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: palmer-api
  minReplicas: {{ .Values.autoscaling.minReplicas | default 1 }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas | default 5 }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage | default 60 }}
{{- end }}
"

echo "✅ Helm chart ready in $CHART"
echo "Run: helm template palmer ./$CHART | less   # preview"
echo "     helm install palmer ./$CHART --create-namespace --namespace $NS"

