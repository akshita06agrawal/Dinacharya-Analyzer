# 🪷 Dinacharya Analyzer — Cloud-Native DevOps Project

[![CI/CD Pipeline](https://github.com/your-username/dinacharya-analyzer/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/your-username/dinacharya-analyzer/actions)
[![Docker Image](https://img.shields.io/docker/v/your-username/dinacharya-analyzer?label=docker)](https://hub.docker.com/r/your-username/dinacharya-analyzer)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> A production-grade, cloud-native web application that analyzes daily routines against Vedic Ayurvedic principles — built with a complete DevOps pipeline including Docker, Kubernetes, CI/CD, Infrastructure as Code, and monitoring.

**Live Demo:** https://dinacharya-analyzer.onrender.com

---

## 🏗️ Architecture Overview

```
                    ┌─────────────────────────────────────────┐
                    │            GitHub Repository             │
                    │                                          │
                    │  Push → CI/CD Pipeline (GitHub Actions) │
                    └──────────────┬──────────────────────────┘
                                   │
                    ┌──────────────▼──────────────────────────┐
                    │         CI/CD Pipeline Stages            │
                    │                                          │
                    │  1. Test & Lint (Jest + ESLint)          │
                    │  2. Docker Build (Multi-stage)           │
                    │  3. Security Scan (Trivy)                │
                    │  4. Push to Docker Hub                   │
                    │  5. Deploy to Production                 │
                    └──────────────┬──────────────────────────┘
                                   │
        ┌──────────────────────────▼──────────────────────────┐
        │                  Production Infrastructure           │
        │                                                      │
        │   ┌─────────┐   ┌──────────┐   ┌───────────────┐  │
        │   │  Nginx  │──▶│  App     │──▶│  Anthropic AI │  │
        │   │  Proxy  │   │  (Node)  │   │     API       │  │
        │   └─────────┘   └────┬─────┘   └───────────────┘  │
        │                      │                              │
        │   ┌──────────────────▼───────────────────────────┐ │
        │   │          Monitoring Stack                     │ │
        │   │   Prometheus (metrics) → Grafana (dashboards)│ │
        │   └──────────────────────────────────────────────┘ │
        └─────────────────────────────────────────────────────┘
```

---

## 🛠️ Tech Stack & DevOps Skills Demonstrated

| Category | Technology | What it does |
|----------|-----------|--------------|
| **Backend** | Node.js + Express | REST API, health checks, structured logging |
| **Containerization** | Docker (multi-stage) | Optimized image build, non-root user, health checks |
| **Orchestration** | Kubernetes | Deployments, HPA, liveness/readiness probes, rolling updates |
| **CI/CD** | GitHub Actions | Automated test → build → scan → deploy pipeline |
| **IaC** | Terraform | AWS EC2, Security Groups, IAM, remote state in S3 |
| **Monitoring** | Prometheus + Grafana | Custom metrics, dashboards, alerting |
| **Security** | Trivy, Helmet.js | Container scanning, HTTP security headers |
| **Reverse Proxy** | Nginx | Load balancing, SSL termination, rate limiting |
| **Cloud** | AWS / Render | EC2 deployment, managed hosting |

---

## 🚀 Quick Start

### Option 1: Docker (Recommended — 1 command)
```bash
# Clone the repo
git clone https://github.com/your-username/dinacharya-analyzer.git
cd dinacharya-analyzer

# Add your API key
echo "ANTHROPIC_API_KEY=your-key-here" > .env

# Run with Docker Compose (starts app + monitoring)
docker compose up -d

# App:      http://localhost:3000
# Metrics:  http://localhost:9090
# Grafana:  http://localhost:3001 (admin/admin123)
```

### Option 2: Local Development
```bash
npm install
cp .env.example .env  # Add your ANTHROPIC_API_KEY
npm run dev           # Starts with hot-reload
```

### Option 3: Kubernetes
```bash
# Create namespace and deploy
kubectl apply -f infrastructure/k8s/

# Check deployment
kubectl get pods -n dinacharya
kubectl get svc -n dinacharya

# View logs
kubectl logs -n dinacharya -l app=dinacharya -f
```

---

## 📁 Project Structure

```
dinacharya-analyzer/
│
├── 🐳 Dockerfile                    # Multi-stage production build
├── 🐳 docker-compose.yml            # Full stack (app + nginx + monitoring)
├── 📦 package.json                  # Dependencies and npm scripts
│
├── backend/
│   ├── server.js                    # Express API (health, metrics, analyze)
│   └── server.test.js               # Jest unit tests
│
├── frontend/
│   └── public/
│       └── index.html               # Complete SPA frontend
│
├── infrastructure/
│   ├── terraform/
│   │   └── main.tf                  # AWS EC2 + Security Groups + IAM
│   ├── k8s/
│   │   └── deployment.yaml          # Deployment + Service + HPA + Ingress
│   └── nginx/
│       └── nginx.conf               # Reverse proxy config
│
├── monitoring/
│   └── prometheus.yml               # Metrics scraping config
│
├── scripts/
│   └── deploy.sh                    # Automated deployment script
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml                # GitHub Actions pipeline
│
└── docs/
    └── architecture.md              # Architecture decisions
```

---

## 🔄 CI/CD Pipeline

Every `git push` to `main` triggers this automated pipeline:

```
Push to GitHub
      │
      ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Test &    │───▶│   Docker    │───▶│  Security   │───▶│   Deploy    │
│   Lint      │    │   Build     │    │   Scan      │    │ Production  │
│             │    │             │    │  (Trivy)    │    │             │
│ Jest + ESLint│   │Multi-stage │    │CVE scanning │    │ Render/AWS  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

**To set up GitHub Secrets** (Settings → Secrets → Actions):
```
DOCKERHUB_USERNAME    → Your Docker Hub username
DOCKERHUB_TOKEN       → Docker Hub access token
ANTHROPIC_API_KEY     → Your Anthropic API key
RENDER_API_KEY        → Render deployment key (optional)
```

---

## 🏥 Health & Monitoring Endpoints

| Endpoint | Purpose | Used by |
|----------|---------|---------|
| `GET /health` | Liveness check — is app running? | Kubernetes, load balancer |
| `GET /ready` | Readiness check — can app serve traffic? | Kubernetes |
| `GET /metrics` | Prometheus metrics | Prometheus scraper |
| `POST /api/analyze` | Main analysis API | Frontend |

**Sample health response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-04-11T10:30:00Z",
  "uptime": "3600s",
  "environment": "production",
  "version": "1.0.0"
}
```

---

## 🔒 Security Features

- **Non-root Docker container** — runs as UID 1001
- **Multi-stage Docker build** — no dev dependencies in production image
- **Helmet.js** — sets secure HTTP headers (CSP, HSTS, X-Frame-Options)
- **Rate limiting** — 100 requests per 15 minutes per IP
- **Input validation** — prompt size limits, type checking
- **Trivy scanning** — CI/CD scans image for CVEs before deployment
- **Secrets management** — API keys via env vars, never in code
- **Terraform sensitive vars** — API keys marked `sensitive = true`

---

## 📊 Kubernetes Features

- **Horizontal Pod Autoscaler** — scales 2→10 pods based on CPU/memory
- **Rolling updates** — zero downtime deployments
- **Liveness probes** — auto-restart unhealthy pods
- **Readiness probes** — no traffic until pod is ready
- **Resource limits** — prevents one pod from consuming all resources
- **Graceful shutdown** — SIGTERM handler for clean pod termination

---

## 🌱 Terraform Features

- **Remote state** — stored in S3 with DynamoDB locking
- **Input validation** — environment variable validation
- **Sensitive variables** — API keys hidden from plan output
- **Default tags** — all resources tagged with project/environment
- **User data script** — auto-installs Docker and runs app on first boot

---

## 🧪 Running Tests

```bash
npm test                  # Run all tests
npm test -- --coverage    # With coverage report
npm test -- --watch       # Watch mode for development
```

**Test coverage includes:**
- Health endpoint returns 200
- Metrics endpoint returns Prometheus format
- Invalid prompt returns 400
- Oversized prompt returns 400
- Security headers present
- CORS headers present

---



*Built as a DevOps portfolio project demonstrating Docker, Kubernetes, CI/CD, Terraform, and monitoring.*
