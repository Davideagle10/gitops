# GitOps Lab — EKS + ArgoCD + Kubernetes

> **Lab** | GitOps Pull Deployment model using ArgoCD on AWS EKS  
> Designed to demonstrate infrastructure as code, GitOps principles, and Kubernetes application delivery.

---

## 📋 Table of Contents

- [What is this lab about](#what-is-this-lab-about)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Infrastructure](#infrastructure)
- [GitOps Flow](#gitops-flow)
- [Prerequisites](#prerequisites)
- [Deployment Guide](#deployment-guide)
- [Accessing ArgoCD](#accessing-argocd)
- [App of Apps Pattern](#app-of-apps-pattern)
- [Applications](#applications)
- [Known Issues](#known-issues)
- [Teardown](#teardown)

---

## What is this lab about

This lab demonstrates a **GitOps Pull Deployment model** using ArgoCD on AWS EKS.

### Push vs Pull — The key concept

Most CI/CD pipelines work in **push mode**: a pipeline runs and actively deploys changes to the cluster by running `kubectl apply` or `helm upgrade`. The pipeline pushes changes into the cluster.

**GitOps Pull mode** inverts this flow. An agent running **inside** the cluster (ArgoCD) constantly watches the Git repository. When it detects a change, it pulls and applies it automatically. No external system pushes anything into the cluster.

```
Push Model (traditional CI/CD):
Pipeline → kubectl/helm → Cluster

Pull Model (GitOps):
Git ← ArgoCD watches constantly
ArgoCD → applies changes → Cluster
```

**Benefits of the Pull model:**
- Git is the single source of truth
- No external credentials needed to access the cluster
- Automatic drift detection — if someone changes something manually, ArgoCD reverts it
- Full audit trail via Git history

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      AWS Account                        │
│                                                         │
│  ┌──────────────────────────────────────────────────┐  │
│  │                    VPC                           │  │
│  │                                                  │  │
│  │  ┌─────────────┐      ┌─────────────────────┐   │  │
│  │  │ Public      │      │ Private Subnets     │   │  │
│  │  │ Subnets     │      │                     │   │  │
│  │  │ (3 AZs)     │      │  ┌───────────────┐  │   │  │
│  │  │             │      │  │  EKS Cluster  │  │   │  │
│  │  │  NAT GW     │      │  │               │  │   │  │
│  │  │  IGW        │      │  │  ┌─────────┐  │  │   │  │
│  │  └─────────────┘      │  │  │ ArgoCD  │  │  │   │  │
│  │                       │  │  ├─────────┤  │  │   │  │
│  │                       │  │  │  nginx  │  │  │   │  │
│  │                       │  │  └─────────┘  │  │   │  │
│  │                       │  └───────────────┘  │   │  │
│  │                       └─────────────────────┘   │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                              ↑
                    ArgoCD watches
                              │
                    ┌─────────────────┐
                    │   GitHub Repo   │
                    │  (this repo)    │
                    └─────────────────┘
```

---

## Repository Structure

```
gitops/
├── apps/                          # Application manifests (ArgoCD deploys these)
│   └── nginx/
│       └── deployment.yaml        # Nginx Deployment + Service
│
├── argo-config/                   # ArgoCD configuration
│   ├── root-application.yaml      # Root App — apply this once manually
│   └── apps/                      # Child Applications — ArgoCD manages these
│       ├── nginx-application.yaml
│       └── prometheus-application.yaml
│
├── infrastructure/                # Terraform — AWS infrastructure
│   ├── main.tf                    # Root module — orchestrates all modules
│   ├── provider.tf                # AWS + Helm providers
│   ├── variables.tf               # Input variables
│   ├── terraform.tfvars           # Variable values (not committed in production)
│   ├── networking/                # VPC, subnets, NAT GW, IGW, route tables
│   ├── eks/                       # EKS cluster, node group, IAM roles, OIDC
│   └── argocd/                    # ArgoCD Helm release
│
└── README.md
```

---

## Infrastructure

All infrastructure is provisioned with **Terraform** and organized in modules:

### Networking module
- VPC with CIDR `10.0.0.0/16`
- 3 Private subnets across 3 Availability Zones
- 3 Public subnets across 3 Availability Zones
- Internet Gateway for public access
- NAT Gateway for private subnet egress
- Route tables for public and private traffic

### EKS module
- EKS Cluster version `1.32`
- Node Group with `t3.medium` instances (On-Demand)
- Scaling: min 1, desired 2, max 4 nodes
- OIDC Provider for IRSA (IAM Roles for Service Accounts)
- IAM roles for cluster and node group with required AWS managed policies

### ArgoCD module
- Deployed via Helm chart (`argo-cd` from `https://argoproj.github.io/argo-helm`)
- Installed in `argocd` namespace
- Exposed via LoadBalancer service (AWS NLB)

---

## GitOps Flow

```
Developer pushes to main
        ↓
GitHub receives the commit
        ↓
ArgoCD detects the change (polling every 3 min or webhook)
        ↓
ArgoCD compares desired state (Git) vs actual state (Cluster)
        ↓
If diff detected → ArgoCD syncs automatically
        ↓
Cluster matches Git — single source of truth
```

**Self-healing:** If someone manually modifies a resource in the cluster, ArgoCD detects the drift and reverts it to match what's in Git.

**Pruning:** If a resource is removed from Git, ArgoCD removes it from the cluster automatically.

---

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.5
- kubectl
- helm >= 3.0
- Git

---

## Deployment Guide

### Step 1 — Deploy Infrastructure

```bash
cd infrastructure

# Initialize Terraform and download providers
terraform init

# Review what will be created
terraform plan

# Deploy VPC + EKS + ArgoCD (~15-20 minutes)
terraform apply
```

This creates:
- VPC with networking components
- EKS cluster with worker nodes
- ArgoCD installed via Helm on the cluster

### Step 2 — Configure kubectl

After the apply completes, configure kubectl to connect to the new cluster:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name main
```

Verify connectivity:

```bash
kubectl get nodes
kubectl get pods -n argocd
```

### Step 3 — Access ArgoCD and get credentials

Get the initial admin password:

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

> **Note:** Save this password — you'll need it to log into the UI.

### Step 4 — Apply the Root Application

This is the **only manual step** in the GitOps flow. You apply the root Application once, and from that point ArgoCD manages everything else automatically:

```bash
kubectl apply -f argo-config/root-application.yaml
```

ArgoCD will:
1. Read `argo-config/apps/`
2. Find `nginx-application.yaml` and `prometheus-application.yaml`
3. Create both Applications automatically
4. Sync and deploy nginx and prometheus-stack

From this point, any push to the `main` branch triggers an automatic sync.

---

## Accessing ArgoCD

### Option 1 — Port Forward (local access)

```bash
kubectl port-forward service/argocd-server 8080:80 -n argocd
```

Open your browser at `http://localhost:8080`

- **Username:** `admin`
- **Password:** obtained in Step 3 above

### Option 2 — LoadBalancer URL

```bash
kubectl get service argocd-server -n argocd
```

Use the `EXTERNAL-IP` value directly in the browser on port `80` or `443`.

### ArgoCD UI Ports Reference

| Service | Port | Purpose |
|---|---|---|
| argocd-server | 80 / 443 | Web UI and API |
| argocd-repo-server | 8081 | Repository management |
| argocd-dex-server | 5556 / 5557 | SSO / Authentication |
| argocd-redis | 6379 | Internal cache |
| argocd-applicationset-controller | 7000 | ApplicationSet controller |

---

## App of Apps Pattern

This lab implements the **App of Apps** pattern, which is the recommended GitOps pattern for managing multiple applications.

### How it works

Instead of applying each Application manually with `kubectl`, you apply a single **root Application** that points to a directory containing other Application manifests. ArgoCD reads that directory and creates all child Applications automatically.

```
root-application (applied once manually)
        │
        └── watches: argo-config/apps/
                │
                ├── nginx-application     → deploys apps/nginx/
                └── prometheus-application → deploys Helm chart
```

### Why this pattern

- **One command to rule them all** — `kubectl apply -f root-application.yaml` is the only manual step
- **Self-managing** — add a new app by dropping a YAML file in `argo-config/apps/` and pushing to Git
- **Scalable** — works the same whether you have 2 or 200 applications
- **Auditable** — every application addition/removal is tracked in Git history

---

## Applications

### Nginx

Simple Nginx deployment to demonstrate the GitOps sync behavior.

**Manifests location:** `apps/nginx/deployment.yaml`  
**Namespace:** `default`  
**Resources:** Deployment (1 replica) + ClusterIP Service on port 80

To verify:
```bash
kubectl get pods -n default
kubectl get service nginx -n default
```

### kube-prometheus-stack

Full monitoring stack including Prometheus, Grafana, and Alertmanager.

**Chart:** `kube-prometheus-stack` from `https://prometheus-community.github.io/helm-charts`  
**Version:** `69.3.2`  
**Namespace:** `monitoring` (created automatically by ArgoCD)

To access Grafana after sync:
```bash
kubectl port-forward svc/prometheus-stack-grafana 3000:80 -n monitoring
```

Open `http://localhost:3000`
- **Username:** `admin`
- **Password:** `prom-operator`

---

## Known Issues

### kube-prometheus-stack CRD size issue

When deploying `kube-prometheus-stack` via ArgoCD, you may encounter this error:

```
[CustomResourceDefinition] "alertmanagerconfigs.monitoring.coreos.com" is invalid:
metadata.annotations: Too long: may not be more than 262144 bytes
```

**Root cause:** The Prometheus Operator CRDs have annotations that exceed Kubernetes' 262144 byte limit. This is a [known issue](https://github.com/prometheus-community/helm-charts/issues/1500) with the chart when deployed through ArgoCD.

**Solution:** Install the CRDs separately before the main chart by splitting into two Applications — one that installs only the Prometheus Operator (which registers the CRDs), and a second wave that installs the full stack after the CRDs are ready.

Add a `prometheus-crds-application.yaml` in `argo-config/apps/`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: prometheus-crds
  namespace: argocd
spec:
  project: default
  source:
    chart: kube-prometheus-stack
    repoURL: https://prometheus-community.github.io/helm-charts
    targetRevision: 69.3.2
    helm:
      values: |
        defaultRules:
          create: false
        alertmanager:
          enabled: false
        grafana:
          enabled: false
        kubeApiServer:
          enabled: false
        kubelet:
          enabled: false
        kubeControllerManager:
          enabled: false
        coreDns:
          enabled: false
        kubeEtcd:
          enabled: false
        kubeScheduler:
          enabled: false
        kubeProxy:
          enabled: false
        kubeStateMetrics:
          enabled: false
        nodeExporter:
          enabled: false
        prometheusOperator:
          enabled: true
        prometheus:
          enabled: false
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

Then update `prometheus-application.yaml` to use sync wave `1` so it deploys after the CRDs:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

---

## Teardown

To destroy all infrastructure and avoid AWS charges:

```bash
cd infrastructure

# This will destroy EKS, VPC, and all associated resources
terraform destroy
```

> ⚠️ **Warning:** This is irreversible. All cluster data will be lost.

---

## Key Concepts Learned

| Concept | Description |
|---|---|
| GitOps Pull Model | Cluster pulls from Git instead of pipeline pushing to cluster |
| ArgoCD | GitOps operator that watches Git and syncs the cluster |
| App of Apps | Pattern where one ArgoCD Application manages other Applications |
| Self-healing | ArgoCD reverts manual cluster changes to match Git |
| Drift detection | ArgoCD detects when cluster state differs from Git |
| Sync Waves | Ordered deployment — wave 0 before wave 1 |
| IaC with Terraform | Infrastructure defined as code, reproducible and versionable |

---

*Built as part of a GitOps learning path — EKS + ArgoCD + Terraform*