# eg-helm — Production Helm Charts

Single GKE cluster · two namespaces (`dev` / `prod`) · two services (`eg-web` + `eg-strapi`)

---

## Repository Structure

```
eg-helm/
├── charts/
│   ├── eg-web/
│   │   ├── Chart.yaml
│   │   ├── values.yaml           # base defaults
│   │   ├── values-dev.yaml       # dev overrides  → namespace: dev,  registry: eg-web-dev
│   │   ├── values-prod.yaml      # prod overrides → namespace: prod, registry: eg-web-prod
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       ├── ingress.yaml
│   │       ├── hpa.yaml
│   │       ├── pdb.yaml
│   │       ├── networkpolicy.yaml
│   │       ├── serviceaccount.yaml
│   │       ├── configmap.yaml
│   │       ├── external-secret.yaml
│   │       └── tests/
│   │           └── test-suite.yaml   # 5 helm tests
│   └── eg-strapi/
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── values-dev.yaml
│       ├── values-prod.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── deployment.yaml       # strategy: Recreate (RWO PVC)
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── hpa.yaml
│           ├── pdb.yaml
│           ├── pvc.yaml              # helm.sh/resource-policy: keep
│           ├── networkpolicy.yaml
│           ├── serviceaccount.yaml
│           ├── configmap.yaml
│           ├── external-secret.yaml
│           └── tests/
│               └── test-suite.yaml  # 4 helm tests (incl. PVC write test)
└── .github/
    └── workflows/
        ├── pr-lint.yml       # PR → helm lint + template (both envs)
        ├── deploy-dev.yml    # push to main → build dev images → deploy dev
        └── deploy-prod.yml   # git tag v*.*.* → build prod images → diff → approve → deploy prod
```

---

## Artifact Registries

| Service     | Env  | Registry |
|-------------|------|----------|
| eg-web      | dev  | `asia-south1-docker.pkg.dev/MY_GCP_PROJECT/eg-web-dev` |
| eg-web      | prod | `asia-south1-docker.pkg.dev/MY_GCP_PROJECT/eg-web-prod` |
| eg-strapi   | dev  | `asia-south1-docker.pkg.dev/MY_GCP_PROJECT/eg-strapi-dev` |
| eg-strapi   | prod | `asia-south1-docker.pkg.dev/MY_GCP_PROJECT/eg-strapi-prod` |

---

## CI/CD Flow

### Dev (push to `main`)
```
push to main
  └─ build eg-web    → push to eg-web-dev    (tag: $SHA)
  └─ build eg-strapi → push to eg-strapi-dev (tag: $SHA)
  └─ deploy-dev
       ├─ helm diff   eg-web    (printed to job summary)
       ├─ helm upgrade eg-web   --atomic --timeout 5m
       ├─ helm test   eg-web
       ├─ helm diff   eg-strapi
       ├─ helm upgrade eg-strapi --atomic --timeout 8m
       └─ helm test   eg-strapi
```

### Prod (push tag `v*.*.*`)
```
git tag v1.4.2 && git push --tags
  └─ build eg-web    → push to eg-web-prod    (tag: v1.4.2)
  └─ build eg-strapi → push to eg-strapi-prod (tag: v1.4.2)
  └─ helm-diff       (diff visible in job summary BEFORE approval)
  └─ approve-prod    ← GitHub Environment: required reviewer must approve
  └─ deploy-prod
       ├─ helm upgrade eg-web    --atomic --timeout 5m
       ├─ helm test   eg-web
       ├─ helm upgrade eg-strapi --atomic --timeout 8m
       ├─ helm test   eg-strapi
       └─ on failure → helm rollback both services automatically
```

---

## GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `GCP_PROJECT` | GCP project ID |
| `GKE_CLUSTER` | GKE cluster name |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | WIF provider resource name |
| `GCP_SERVICE_ACCOUNT` | Service account email for WIF |

### GitHub Environment Setup
Create two GitHub Environments (`dev`, `prod`) under **Settings → Environments**.
For `prod`, add required reviewers — this is the manual approval gate.

---

## Helm Test Coverage

### eg-web (5 tests)
| Test | What it checks |
|------|---------------|
| `test-liveness` | `/healthz` returns HTTP 200 |
| `test-readiness` | `/readyz` returns HTTP 200 |
| `test-secrets` | `API_KEY`, `DATABASE_URL` injected and non-empty |
| `test-dns` | Service DNS resolves in cluster |
| `test-network` | TCP port reachable via Service |

### eg-strapi (4 tests)
| Test | What it checks |
|------|---------------|
| `test-health` | `/_health` returns HTTP 200 (retries 10x) |
| `test-secrets` | All 10 Strapi env secrets injected and non-empty |
| `test-pvc` | PVC mount is writable at `/app/public/uploads` |
| `test-network` | DNS + TCP port reachable via Service |

---

## One-Time Cluster Setup

```bash
# 1. Replace placeholders
grep -r "MY_GCP_PROJECT\|MY_CLUSTER_NAME" charts/ --include="*.yaml" -l

# 2. Create namespaces
kubectl create namespace dev
kubectl create namespace prod
kubectl label namespace dev environment=dev
kubectl label namespace prod environment=prod

# 3. Install ESO
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install eso external-secrets/external-secrets \
  -n external-secrets --create-namespace

# 4. Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace --set installCRDs=true

# 5. Create GCP Secrets (dev)
for SECRET in eg-web-dev-api-key eg-web-dev-database-url \
              eg-strapi-dev-database-client eg-strapi-dev-database-host \
              eg-strapi-dev-database-port eg-strapi-dev-database-name \
              eg-strapi-dev-database-username eg-strapi-dev-database-password \
              eg-strapi-dev-jwt-secret eg-strapi-dev-admin-jwt-secret \
              eg-strapi-dev-app-keys eg-strapi-dev-api-token-salt; do
  echo -n "REPLACE_ME" | gcloud secrets create $SECRET --data-file=- --project=MY_GCP_PROJECT
done

# 6. Workload Identity bindings (repeat for each SA / namespace)
gcloud iam service-accounts create eg-web-sa --project=MY_GCP_PROJECT
gcloud projects add-iam-policy-binding MY_GCP_PROJECT \
  --member="serviceAccount:eg-web-sa@MY_GCP_PROJECT.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
gcloud iam service-accounts add-iam-policy-binding \
  eg-web-sa@MY_GCP_PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:MY_GCP_PROJECT.svc.id.goog[dev/eg-web-sa]"
# Repeat for eg-strapi-sa, and for prod namespace

# 7. Apply ClusterSecretStore (once per cluster)
helm template eg-web ./charts/eg-web \
  -f ./charts/eg-web/values.yaml \
  -f ./charts/eg-web/values-dev.yaml \
  --set image.tag=bootstrap \
  -s templates/cluster-secret-store.yaml \
  --namespace dev | kubectl apply -f -
```

---

## Manual Deploy (without CI)

```bash
# Dev
helm upgrade --install eg-web ./charts/eg-web \
  -f charts/eg-web/values.yaml -f charts/eg-web/values-dev.yaml \
  --set image.tag=<SHA> --namespace dev --atomic

# Prod
helm upgrade --install eg-strapi ./charts/eg-strapi \
  -f charts/eg-strapi/values.yaml -f charts/eg-strapi/values-prod.yaml \
  --set image.tag=v1.4.2 --namespace prod --atomic

# Run tests manually
helm test eg-web --namespace dev --logs
helm test eg-strapi --namespace prod --logs

# Rollback
helm rollback eg-web 0 --namespace prod   # 0 = previous release
```
