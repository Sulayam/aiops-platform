Let’s build you **clean, modernized notes** that reflect what we actually did, replacing Nana’s old `hyperkit` workflow with **Colima + Homebrew Docker**, and folding in all the troubleshooting and fixes (like Docker Desktop conflicts, `$PATH` fixes, etc.).

---

# 🚀 Kubernetes Setup with Minikube + Colima (macOS)

### 🔧 Install prerequisites

```bash
brew update
brew install colima
brew install minikube
brew install kubectl
```

---

### 🐳 Setup Docker with Colima

By default, `docker` on macOS can point to **Docker Desktop’s socket**. We want it to use **Colima’s lightweight VM backend** instead.

1. **Start Colima VM**

   ```bash
   colima start --cpu 4 --memory 8 --disk 40
   ```

2. **Check status**

   ```bash
   colima status
   ```

   You should see:

   * `runtime: docker`
   * `docker socket: unix:///Users/<username>/.colima/default/docker.sock`

3. **Switch docker context to Colima**

   ```bash
   docker context ls
   docker context use colima
   ```

   Now `docker ps` talks to Colima’s daemon, not Docker Desktop.

4. **(Optional safety)** If Docker Desktop also installed its own `kubectl` or `docker`, make sure Homebrew’s versions come first in `$PATH`.

   ```bash
   echo $PATH
   which kubectl
   ls -l $(which -a kubectl)
   ```

   * Keep `/opt/homebrew/bin/kubectl` (v1.34.1) above `/usr/local/bin/kubectl` (old Docker Desktop v1.32.2).
   * If needed, add this to `~/.zshrc`:

     ```bash
     export PATH="/opt/homebrew/bin:$PATH"
     ```
   * Then reload:

     ```bash
     source ~/.zshrc
     hash -r   # clear zsh’s command cache
     ```

---
Colima is eating CPU + RAM in the background because it’s a VM. If you’re not actively using Kubernetes, best practice is to stop it. Here’s the safe sequence:

### 🔻 Stop (to free resources)

```bash
# Stop Minikube cluster
minikube stop

# Stop Colima VM
colima stop
```

At this point, Docker containers, Kubernetes nodes, and the VM all pause. Your configs (YAMLs, deployments) remain intact.

---

### 🔺 Start (when you need it again)

```bash
# Start Colima VM (allocate resources back)
colima start --cpu 4 --memory 8 --disk 40

# Start Minikube cluster inside Colima
minikube start --driver=docker
```

---

### ✅ Verify

```bash
minikube status
kubectl get nodes
kubectl get pods -A   # all namespaces
```

You should see your old Deployments and Services. Pods may restart with fresh IPs, but functionality stays the same.

---

### 🎡 Create and manage Minikube cluster

1. **Start cluster inside Colima’s Docker**

   ```bash
   minikube start --driver=docker
   ```

   * Uses Colima’s Docker backend (if `docker context` is `colima`).
   * Sets up a single-node Kubernetes cluster.

2. **Check cluster**

   ```bash
   kubectl get nodes
   minikube status
   kubectl version
   ```

   Example output:

   ```
   NAME       STATUS   ROLES           AGE   VERSION
   minikube   Ready    control-plane   2m    v1.34.0
   ```

---

### 🛠️ Basic kubectl commands

* **Cluster info**

  ```bash
  kubectl get nodes
  kubectl get pods
  kubectl get services
  kubectl get all
  ```

* **Deployments**

  ```bash
  kubectl create deployment nginx-depl --image=nginx
  kubectl get deployment
  kubectl get replicaset
  kubectl edit deployment nginx-depl   # fix image version, replicas, etc.
  ```

* **Debugging**

  ```bash
  kubectl logs <pod-name>
  kubectl describe pod <pod-name>
  kubectl exec -it <pod-name> -- /bin/bash   # or /bin/sh
  ```

---

### 📦 Creating Deployments with YAML

* **Nginx example**
  `k8-nginx-config.yaml`:

  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: nginx-depl
  spec:
    replicas: 2
    selector:
      matchLabels:
        app: nginx
    template:
      metadata:
        labels:
          app: nginx
      spec:
        containers:
        - name: nginx
          image: nginx:1.16
          ports:
          - containerPort: 80
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: nginx-service
  spec:
    type: NodePort
    selector:
      app: nginx
    ports:
      - protocol: TCP
        port: 80
        targetPort: 80
        nodePort: 30080
  ```

* **MongoDB example**
  `k8-mongo-config.yaml`:

  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: mongo-depl
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: mongo
    template:
      metadata:
        labels:
          app: mongo
      spec:
        containers:
        - name: mongo
          image: mongo:6.0
          ports:
          - containerPort: 27017
  ---
  apiVersion: v1
  kind: Service
  metadata:
    name: mongo-service
  spec:
    selector:
      app: mongo
    ports:
      - protocol: TCP
        port: 27017
        targetPort: 27017
  ```

* **Apply / delete**

  ```bash
  kubectl apply -f k8-nginx-config.yaml
  kubectl apply -f k8-mongo-config.yaml

  kubectl delete -f k8-nginx-config.yaml
  kubectl delete -f k8-mongo-config.yaml
  ```

---

### 🔄 Cluster maintenance

* **Delete and restart**

  ```bash
  minikube delete
  minikube start --driver=docker --v=7 --alsologtostderr
  ```

* **Metrics (needs metrics-server addon)**

  ```bash
  kubectl top nodes
  kubectl top pods
  ```

---

✅ With these notes, you’ve got:

* Correct **Colima setup** (no Docker Desktop conflict).
* Correct **kubectl version handling**.
* Deployment + Service YAML examples for **nginx** and **mongo**.
* Debugging + exec workflow.
* Cluster lifecycle commands.

---

Do you want me to also add a **troubleshooting section** (like the kubectl PATH issue and immutable field error when re-applying YAML)? That way you’ll have a ready-made checklist when things break.


Perfect — here’s a **Troubleshooting Section** you can paste directly into your markdown notes:

---

## 🛑 Troubleshooting Cheatsheet

### 1. **kubectl wrong version**

* **Symptom**: `kubectl version` shows old client (e.g., v1.32.2 from Docker Desktop).
* **Cause**: Multiple `kubectl` binaries on your system (`/usr/local/bin/kubectl` vs `/opt/homebrew/bin/kubectl`).
* **Fix**:

  ```bash
  which -a kubectl     # list all kubectl binaries
  ls -l $(which -a kubectl)
  ```

  Prioritize Homebrew’s version in `~/.zshrc`:

  ```bash
  export PATH="/opt/homebrew/bin:$PATH"
  source ~/.zshrc
  hash -r
  ```

  ✅ Now `which kubectl` should point to `/opt/homebrew/bin/kubectl` (Homebrew v1.34.x).

---

### 2. **Deployment selector immutable error**

* **Symptom**:

  ```
  The Deployment "xxx" is invalid: spec.selector: Invalid value: ...
  ```
* **Cause**: You changed `spec.selector.matchLabels` in a Deployment YAML after creation. That field can’t be changed.
* **Fix**:

  * Delete and re-create the deployment:

    ```bash
    kubectl delete deployment <name>
    kubectl apply -f <file>.yaml
    ```

---

### 3. **Pod keeps terminating / restarting**

* Check logs:

  ```bash
  kubectl logs <pod-name>
  ```
* Check detailed pod events:

  ```bash
  kubectl describe pod <pod-name>
  ```
* Common issues:

  * Wrong image tag → fix `image: nginx:1.16`
  * Port mismatch between container and service.

---

### 4. **Colima vs Docker Desktop confusion**

* **Symptom**: Minikube says `Using Docker Desktop driver...` even when Colima is running.
* **Fix**: Make sure Docker CLI points to Colima:

  ```bash
  docker context use colima
  export DOCKER_HOST=unix://${HOME}/.colima/default/docker.sock
  ```
* Verify:

  ```bash
  docker ps
  ```

  If it shows your minikube container, you’re good.

---

### 5. **Exit without saving in vim**

* Press `Esc`
* Type `:q!` → exit without saving
* Type `:wq` → save and quit

---

✅ With these fixes, you can recover from the most common beginner Kubernetes + Colima issues.

---

Here’s a **diagram-style summary** you can drop straight into your notes:

---

## 🔄 Kubernetes Object Relationships

```
                 ┌──────────────────┐
                 │   Deployment     │
                 │  (nginx-depl)    │
                 └───────┬──────────┘
                         │ manages
                         ▼
                 ┌──────────────────┐
                 │   ReplicaSet     │
                 │ (e.g. hash ID)   │
                 └───────┬──────────┘
                         │ ensures N replicas
                         ▼
        ┌─────────────────────────────────┐
        │             Pods                │
        │ ┌───────────────┐  ┌──────────┐ │
        │ │ Pod: nginx-1  │  │ Pod: ... │ │
        │ │ Container:    │  │ Container│ │
        │ │ nginx:1.16    │  │ nginx:1.16│ │
        │ └───────────────┘  └──────────┘ │
        └─────────────────────────────────┘
                         ▲
                         │ exposed by
                         ▼
                 ┌──────────────────┐
                 │     Service      │
                 │  ClusterIP/Node  │
                 └────────┬─────────┘
                          │ routes traffic
                          ▼
                    User / Browser
```

---

### 🗂️ Quick mental model

* **Deployment** → Blueprint + desired state (e.g. “2 Pods of nginx:1.16”).
* **ReplicaSet** → Watches Pods, recreates if deleted.
* **Pods** → Actual running containers.
* **Service** → Gives Pods a stable endpoint (IP/port), handles load balancing.
* **NodePort Service** → Opens cluster traffic on `localhost:<NodePort>` for external access.

---

👉 With this picture in mind, debugging is easier:

* Pod crashes? → ReplicaSet replaces it.
* Wrong image? → Fix Deployment → new ReplicaSet → new Pods.
* Can’t access app? → Check Service type + ports.

---
