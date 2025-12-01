# K8s Cost Compass 🧭💰

> Real-time cost visibility for Kubernetes clusters - helping engineering teams understand the financial impact of their architectural decisions.

## The Problem

Engineering teams make Kubernetes resource decisions (CPU/memory requests, node types, autoscaling configs) without understanding their cost implications until the cloud bill arrives. This leads to:
- Over-provisioned resources wasting 40-60% of cluster spend
- Under-provisioned resources causing performance issues
- Lack of visibility into which teams/namespaces drive costs
- Inability to answer "what if we change X?" questions

## The Solution

K8s Cost Compass provides **real-time cost analysis** that shows:
- What you're **paying for** (resource requests) vs what you're **actually using**
- Cost breakdown by namespace, deployment, and pod
- Waste identification and efficiency scoring
- Cost impact projections for architectural changes

## Why This Project Matters

**For CTOs/Engineering Leaders:**
- Demonstrates systems thinking about business impact of technical decisions
- Shows ability to build observability tooling that drives operational decisions
- Bridges gap between infrastructure engineering and financial planning

**For Learning:**
- Deep dive into Kubernetes resource management and scheduling
- Production-grade Go service architecture
- Cost modeling and financial calculations for cloud infrastructure
- Building dashboards that drive business decisions

## Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  K8s API     │  │ Metrics      │  │ Prometheus   │      │
│  │  Server      │  │ Server       │  │ (optional)   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
└─────────┼──────────────────┼──────────────────┼──────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│              K8s Cost Compass System                         │
│                                                              │
│  ┌────────────────┐      ┌────────────────┐                │
│  │ Data Collector │─────▶│ Cost Calculator│                │
│  │  (Go Service)  │      │  (Go Service)  │                │
│  └────────┬───────┘      └────────┬───────┘                │
│           │                       │                         │
│           ▼                       ▼                         │
│  ┌────────────────┐      ┌────────────────┐                │
│  │  PostgreSQL    │◀─────│  Redis Cache   │                │
│  │  (Historical)  │      │  (Hot Data)    │                │
│  └────────┬───────┘      └────────┬───────┘                │
│           │                       │                         │
│           └───────┬───────────────┘                         │
│                   ▼                                         │
│           ┌────────────────┐                                │
│           │   REST API     │                                │
│           │  (Go Service)  │                                │
│           └────────┬───────┘                                │
└────────────────────┼────────────────────────────────────────┘
                     │
                     ▼
            ┌────────────────┐
            │     React      │
            │   Dashboard    │
            └────────────────┘
```

### Core Components

**1. Data Collector Service**
- Runs every 5 minutes
- Queries K8s API for pods, nodes, deployments
- Scrapes Metrics Server for actual CPU/memory usage
- Persists raw data to PostgreSQL

**2. Cost Calculator Service**
- Event-driven computation engine
- Applies pricing models (GCP/AWS/Azure)
- Calculates waste, efficiency scores, projections
- Updates Redis cache with hot data

**3. REST API Service**
- Serves cost data to dashboard
- Handles "what-if" scenario calculations
- Provides historical cost trends
- Fast reads from Redis, complex queries from PostgreSQL

**4. React Dashboard**
- Visual cost breakdowns and trends
- Namespace/deployment drill-downs
- Waste identification and recommendations
- Interactive what-if calculator

### Cost Calculation Model

```go
// Core cost calculation logic
type CostAnalysis struct {
    // What you're PAYING for (reserved capacity)
    RequestedCPU      float64  // vCPUs requested
    RequestedMemory   float64  // GB requested
    NodeHourlyRate    float64  // Cloud provider pricing
    
    // What you're ACTUALLY using
    ActualCPU         float64  // vCPUs used (avg)
    ActualMemory      float64  // GB used (avg)
    
    // The insights
    HourlyCost        float64  // Actual spend
    WastedCost        float64  // (Requested - Actual) * Rate
    EfficiencyScore   float64  // (Actual / Requested) * 100
    MonthlySavings    float64  // If rightsized
}
```

### Database Schema

```sql
-- Node inventory and pricing
CREATE TABLE nodes (
    id UUID PRIMARY KEY,
    name VARCHAR(255),
    node_type VARCHAR(100),
    cpu_capacity FLOAT,
    memory_capacity FLOAT,
    hourly_cost DECIMAL(10,4),
    created_at TIMESTAMP
);

-- Pod resource allocations
CREATE TABLE pods (
    id UUID PRIMARY KEY,
    namespace VARCHAR(255),
    name VARCHAR(255),
    node_id UUID REFERENCES nodes(id),
    cpu_request FLOAT,
    memory_request FLOAT,
    created_at TIMESTAMP
);

-- Actual usage snapshots
CREATE TABLE usage_snapshots (
    id UUID PRIMARY KEY,
    pod_id UUID REFERENCES pods(id),
    cpu_usage FLOAT,
    memory_usage FLOAT,
    timestamp TIMESTAMP
);

-- Aggregated cost calculations
CREATE TABLE cost_calculations (
    id UUID PRIMARY KEY,
    namespace VARCHAR(255),
    deployment VARCHAR(255),
    daily_cost DECIMAL(10,2),
    wasted_cost DECIMAL(10,2),
    efficiency_score FLOAT,
    calculation_date DATE
);
```

## Tech Stack

**Backend:**
- Go 1.21+ (K8s client, cost calculations, REST API)
- PostgreSQL 15 (historical data, complex queries)
- Redis 7 (caching, real-time data)

**Frontend:**
- React 18
- Recharts (cost visualizations)
- TailwindCSS (styling)

**Infrastructure:**
- Kubernetes 1.28+
- Helm 3 (deployment)
- Prometheus (optional, for enhanced metrics)

**Development:**
- Minikube (local testing)
- Docker (containerization)
- Make (build automation)

## Week 1 Core Engine (code)

**Binaries**
- `cmd/collector`: pulls pods/nodes + metrics, stores snapshots in Postgres.
- `cmd/calculator`: aggregates latest usage per namespace and writes cost rows.

**Environment**
- `DB_URL` (required): `postgres://user:pass@host:5432/dbname?sslmode=disable`
- `KUBECONFIG` (optional): kubeconfig path; falls back to in-cluster or `~/.kube/config`.
- `COLLECT_INTERVAL` / `CALCULATE_INTERVAL`: defaults to `5m`.
- `CPU_HOURLY` / `MEMORY_GB_HOURLY`: default pricing `0.031` / `0.004`.

**Local environment via Makefile + Docker Compose**
```bash
cp .env.example .env

# start Postgres locally
make env-up

# (optional) open a psql shell
make db-shell

# watch DB logs
make logs

# stop Postgres and remove containers
make env-down
```

**Run locally**
```bash
export DB_URL="postgres://postgres:postgres@localhost:5432/costcompass?sslmode=disable"

# start collector (polls K8s + metrics server)
go run ./cmd/collector

# start calculator in a second terminal (reads DB, writes cost_calculations)
go run ./cmd/calculator
```

**Database schema**
- Auto-created on startup and mirrored in `migrations/001_init.sql`.
- Tables: `nodes`, `pods`, `usage_snapshots`, `cost_calculations`.
- `usage_snapshots` keeps last-known CPU/mem per pod; calculator uses the latest snapshot per pod to compute namespace totals.

## 2-Week Build Plan

### Week 1: Core Engine
**Goal:** Working cost calculation engine with real K8s data

- **Day 1-2:** Project setup, K8s client, resource data collection
- **Day 3-4:** Cost calculation logic, efficiency scoring
- **Day 5-6:** PostgreSQL integration, data persistence
- **Day 7:** Integration testing, mock historical data

### Week 2: Dashboard & Polish
**Goal:** Visual dashboard showing actionable insights

- **Day 8-9:** REST API, Redis caching, endpoints
- **Day 10-11:** React dashboard, cost visualizations
- **Day 12-13:** Waste analysis, what-if calculator, trends
- **Day 14:** Helm chart, documentation, demo

## Key Features

### MVP (Week 1)
- [x] K8s cluster connection and data collection
- [x] Cost calculation based on resource requests
- [x] Namespace-level cost breakdown
- [x] PostgreSQL data persistence
- [x] Efficiency scoring

### Core Value (Week 2)
- [ ] REST API with cost endpoints
- [ ] React dashboard with visualizations
- [ ] Cost trend analysis (7-day history)
- [ ] Top wasteful deployments identification
- [ ] What-if calculator for resource changes

### Future Enhancements
- [ ] Multi-cluster support
- [ ] Slack/email cost alerts
- [ ] Team/label-based cost allocation
- [ ] Rightsizing recommendations engine
- [ ] Budget tracking and forecasting
- [ ] Integration with cloud billing APIs

## Installation

### Prerequisites
- Kubernetes cluster (1.28+)
- kubectl configured
- Helm 3
- PostgreSQL (or use included chart)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/k8s-cost-compass.git
cd k8s-cost-compass

# Install with Helm
helm install cost-compass ./helm/cost-compass \
  --set cloudProvider=gcp \
  --set pricing.cpuHourly=0.031 \
  --set pricing.memoryGBHourly=0.004

# Access the dashboard
kubectl port-forward svc/cost-compass-ui 3000:3000
# Open http://localhost:3000
```

### Configuration

```yaml
# values.yaml
cloudProvider: gcp  # gcp, aws, azure

pricing:
  cpuHourly: 0.031        # Price per vCPU hour
  memoryGBHourly: 0.004   # Price per GB memory hour

collector:
  intervalMinutes: 5      # Data collection frequency
  
calculator:
  enabled: true
  
postgresql:
  enabled: true
  persistence: true
  
redis:
  enabled: true
```

## Usage

### View Cluster Costs

```bash
# Total cluster cost
curl http://localhost:8080/api/v1/costs/total

# Cost by namespace
curl http://localhost:8080/api/v1/costs/namespaces

# Cost by deployment
curl http://localhost:8080/api/v1/costs/namespaces/production/deployments
```

### What-If Analysis

```bash
# Calculate cost impact of resource change
curl -X POST http://localhost:8080/api/v1/whatif \
  -d '{
    "namespace": "production",
    "deployment": "api-server",
    "newCPURequest": 1.0,
    "newMemoryRequest": 2.0
  }'
```

### Dashboard Views

**Cluster Overview:**
- Total monthly cost projection
- Cluster-wide efficiency score
- Cost trend (7 days)

**Namespace Breakdown:**
- Cost per namespace (pie chart)
- Top 5 most expensive namespaces
- Waste by namespace

**Waste Analysis:**
- Top 10 wasteful deployments
- Efficiency scores
- Potential monthly savings

## Development

### Local Setup

```bash
# Start Minikube
minikube start --cpus=4 --memory=8192

# Install dependencies
go mod download

# Run collector locally
go run cmd/collector/main.go

# Run calculator locally
go run cmd/calculator/main.go

# Run API locally
go run cmd/api/main.go
```

### Testing

```bash
# Unit tests
make test

# Integration tests (requires K8s cluster)
make test-integration

# Generate mock data
make generate-mock-data
```

### Building

```bash
# Build all binaries
make build

# Build Docker images
make docker-build

# Run locally with docker-compose
docker-compose up
```

## Learning Outcomes

### Technical Skills
- **Kubernetes Internals:** Deep understanding of resource management, scheduling, metrics
- **Cost Modeling:** Building financial calculation engines for cloud infrastructure
- **Distributed Systems:** Multi-service architecture with data consistency concerns
- **Observability:** Collecting, storing, and visualizing operational data

### CTO-Level Thinking
- **Business Impact:** Connecting technical decisions to financial outcomes
- **Operational Intuition:** Understanding what drives cloud costs in production
- **Communication:** Explaining complex systems to non-technical stakeholders
- **Trade-offs:** Balancing accuracy, complexity, and operational overhead

### Architecture Decisions
- Why three separate services vs monolith?
- PostgreSQL + Redis - when to use each?
- Event-driven vs polling - trade-offs explored
- Caching strategies for hot data

## Design Decisions Log

### Why Separate Collector and Calculator?
**Decision:** Split data collection from cost calculation  
**Reasoning:** Different failure modes, scaling needs, and update frequencies  
**Trade-off:** More operational complexity vs better reliability and flexibility

### Why PostgreSQL + Redis?
**Decision:** PostgreSQL for historical data, Redis for hot data cache  
**Reasoning:** Complex queries need RDBMS, dashboard needs fast reads  
**Trade-off:** Two databases to maintain vs optimal performance for each use case

### Why 5-Minute Collection Interval?
**Decision:** Collect resource data every 5 minutes  
**Reasoning:** Balance between freshness and API load  
**Trade-off:** Near real-time vs cluster API overhead

### Why Mock Pricing vs Cloud APIs?
**Decision:** Start with configurable pricing, add API integration later  
**Reasoning:** Faster MVP, avoids rate limits, works across providers  
**Trade-off:** Manual updates needed vs automatic accuracy

## Contributing

This is a learning project, but contributions are welcome! Areas for improvement:
- Multi-cloud pricing API integration
- Enhanced rightsizing algorithms
- Cost anomaly detection
- Budget alerting system

## License

MIT License - see LICENSE file

## Acknowledgments

Built as part of a 2-week learning sprint to develop CTO-level thinking about infrastructure costs and Kubernetes operations.

**Key Influences:**
- Kubernetes cost management patterns from Kubecost and OpenCost
- Cloud pricing models from GCP, AWS, Azure documentation
- Observability patterns from Prometheus and Grafana ecosystems

---

## Project Status

**Current Phase:** Week 1 - Core Engine Development

**Next Milestone:** Working cost calculator with PostgreSQL integration (Day 7)

**Follow Progress:** Check the `docs/daily-logs/` directory for daily development notes and learnings.
