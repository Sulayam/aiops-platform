Recommended sequence:

1. **Recreate what you saw in the course** on your laptop. Use Minikube/Colima or Docker Desktop with Kubernetes enabled. Deploy sample apps, expose them, scale them.
2. **Apply to your current project.** Containerize the app. Write manifests (Deployment, Service, ConfigMap, Secret). Deploy and test locally.
3. **Add realism.**

   * Use Ingress instead of NodePort.
   * Add persistent storage.
   * Configure namespaces and RBAC.
   * Simulate failures and test rollout/rollback.
4. **Move beyond laptop.** Spin up a managed cluster (EKS, GKE, AKS, or kind/k3s on cloud VMs). Redo the deployment there.
5. **Production topics to learn next:**

   * Helm for packaging.
   * CI/CD integration.
   * Observability (Prometheus, Grafana, logs).
   * Secrets management.
   * Autoscaling and resource requests/limits.

---
# Palmer Project – Resume Later Notes

## Current Status (as of Oct 19, 2025)
- Helm deployment working ✅
- All services (UI, API, Postgres) are deployed via Helm in `palmer` namespace
- Autoscaling (HPA) for API is configured
- PersistentVolumes for API model + Postgres are in use
- Docker image version used: palmer-api:0.7 (includes fallback model)
- PVC model mount still needs verification for live model availability

## What Needs Attention on Resume
- Validate model mounting from PVC (or use fallback strategy)
- Confirm cluster is running and kubectl context is valid
- Possibly clean up/rebuild cluster if versions are outdated

## Commands Used Recently
```bash
# Upgrade helm release
helm upgrade palmer ./palmer-helm --namespace palmer

# Check logs
kubectl logs -n palmer -l app=palmer-api

# Rebuild and load Docker image
docker build -f Dockerfile.api -t palmer-api:0.7 .
docker save palmer-api:0.7 -o palmer-api-0.7.tar
docker load -i palmer-api-0.7.tar
