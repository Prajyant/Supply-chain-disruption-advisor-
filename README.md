# Supply Chain Disruption Advisor

An AI-powered platform that ingests supplier signals, detects disruption risks using predictive cross-referencing, and recommends mitigation actions — with a real-time digital twin, multi-agent debate system, maritime intelligence, and Bedrock-powered advisory chat.

## Features

- **Predictive Risk Detection** — Cross-references supplier emails with live world news to predict disruptions before they hit
- **Multi-Agent Debate System** — 5 specialized agents (cost, risk, speed, supply chain, digital twin) + orchestrator for balanced decision-making
- **Digital Twin** — Interactive supply chain network graph with risk propagation and node-level context cards
- **AI Chat Advisor** — Bedrock Claude-powered chat with full system awareness (risks, shipments, weather, trade, network)
- **Shipment Tracking** — Real-time shipment status with per-shipment risk scoring and resolution packages
- **Maritime Intelligence** — Route calculation, port congestion, sanctions screening, vessel registry, and tariff analysis
- **Vessel Tracking** — AIS-based real-time vessel monitoring with watchlist, danger zones, and silence detection
- **Live Intelligence** — Weather monitoring, trade policy tracking, flight tracking, and world news aggregation
- **Automated Playbooks** — Rule-based automation that triggers actions when risk thresholds are crossed
- **Role-Based Dashboards** — Operations view, CFO view, and standard risk dashboard
- **Real-Time Updates** — WebSocket-based live notifications for risks, network changes, and playbook executions
- **Authentication** — JWT + Firebase Auth with role-based access control (RBAC)
- **Email Alerts** — AWS SES role-routed notifications (operations, finance, analyst, executive)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         React Frontend                               │
│  Dashboard │ Digital Twin │ Chat │ Vessel Tracking │ Playbooks       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ REST + WebSocket
┌──────────────────────────────▼──────────────────────────────────────┐
│                        FastAPI Backend                                │
├─────────────┬──────────────┬──────────────┬─────────────────────────┤
│  Ingestion  │  Retrieval   │  Risk Engine │  Agent Orchestration    │
│  (loaders,  │  (TF-IDF +   │  (XGBoost +  │  (Strands SDK,         │
│   AIS, RSS, │   cosine     │   heuristic  │   multi-agent debate)   │
│   weather)  │   similarity)│   + Bedrock) │                         │
├─────────────┴──────────────┴──────────────┴─────────────────────────┤
│  External Services: Bedrock │ SES │ DynamoDB │ Firebase │ AIS APIs   │
└─────────────────────────────────────────────────────────────────────┘
```

### Backend Structure

```
app/
├── agents/            # Multi-agent debate system
│   ├── base.py               # Base agent class
│   ├── cost_agent.py         # Cost optimization agent
│   ├── risk_agent.py         # Risk assessment agent
│   ├── speed_agent.py        # Delivery speed agent
│   ├── twin_agent.py         # Digital twin simulation agent
│   ├── supply_chain_agent.py # Strands-based supply chain agent
│   └── debate_orchestrator.py# Multi-agent debate coordinator
├── api/               # REST + WebSocket endpoints
│   ├── routes.py             # Main API routes
│   └── vessel_routes.py      # Vessel tracking endpoints
├── auth/              # JWT + Firebase + RBAC
├── background/        # Background job workers (ingestion, risk, propagation)
├── core/              # Configuration (Pydantic settings)
├── db/                # DynamoDB client + data loaders
├── graph/             # Digital twin network model
├── ingestion/         # Data loaders + live intelligence
│   ├── ais/                  # AIS vessel tracking engine
│   │   ├── ais_engine.py     # Core tracking logic + danger zones
│   │   ├── aisstream_provider.py # AISStream WebSocket provider
│   │   ├── demo_provider.py  # Demo/offline provider
│   │   └── vessel_worker.py  # Background polling worker
│   ├── loaders.py            # CSV data ingestion
│   ├── weather_monitor.py    # Open-Meteo weather + marine data
│   ├── trade_monitor.py      # Trade policy event tracking
│   ├── vessel_tracker.py     # Vessel position tracking (IMO)
│   ├── vessel_registry.py    # Equasis inspections + ITU MARS identity
│   ├── route_calculator.py   # Searoute nautical mile distance + ETA
│   ├── sanctions_monitor.py  # OFAC SDN + UN sanctions screening
│   ├── tariff_monitor.py     # WTO/WITS tariff rate monitoring
│   ├── port_congestion.py    # UNCTAD port turnaround + congestion
│   ├── supply_hub.py         # Open Supply Hub facility graph data
│   ├── flight_tracker.py     # Flight/air cargo tracking
│   ├── worldmonitor.py       # World news aggregation
│   └── rss_utils.py          # RSS feed parsing
├── models/            # Pydantic schemas + feedback models
├── retrieval/         # TF-IDF vector search index
├── services/          # Service layer
│   ├── advisor_service.py           # Master orchestrator
│   ├── chat_service.py              # Bedrock-powered chat advisor
│   ├── risk_service.py              # Risk classification engine
│   ├── risk_engine.py               # Severity scoring (LLM + heuristic)
│   ├── shipment_risk_service.py     # Per-shipment risk scoring
│   ├── bedrock_advice_service.py    # Bedrock mitigation advice
│   ├── resolution_service.py        # Resolution package generation
│   ├── strands_orchestrator_service.py # Strands SDK workflow
│   ├── graph_service.py             # Graph operations
│   ├── shipment_tracker.py          # Shipment lifecycle management
│   ├── playbook_engine.py           # Automated playbook evaluation
│   ├── feedback_service.py          # User feedback collection
│   ├── email_service.py             # AWS SES email notifications
│   └── ingestion_service.py         # Ingestion coordination
├── websocket/         # Real-time update manager
└── main.py            # FastAPI entrypoint + lifespan workers
```

### Frontend Structure

```
frontend/
├── src/
│   ├── components/
│   │   ├── GlobalChat.tsx            # Floating AI chat widget
│   │   ├── MaritimeIntelligence.tsx  # Maritime intel overview panel
│   │   ├── VesselMap.tsx             # Interactive vessel map (Leaflet)
│   │   ├── WeatherOverlay.tsx        # Weather visualization
│   │   ├── RiskCard.tsx              # Risk display cards
│   │   ├── ResolutionPackage.tsx     # Resolution action cards
│   │   ├── ShipmentTracker.tsx       # Shipment status component
│   │   ├── NodeDetail.tsx            # Graph node context card
│   │   ├── RouteLines.tsx            # Route visualization
│   │   ├── DangerZoneOverlay.tsx     # Danger zone map overlay
│   │   └── LiveWeatherBanner.tsx     # Live weather strip
│   ├── pages/
│   │   ├── Dashboard.tsx          # Main risk dashboard
│   │   ├── CFODashboard.tsx       # Financial impact view
│   │   ├── OperationsDashboard.tsx# Operations view + maritime strip
│   │   ├── DigitalTwin.tsx        # Network graph visualization
│   │   ├── ShipmentDetail.tsx     # Per-shipment deep dive + maritime intel
│   │   ├── VesselTracking.tsx     # Fleet monitoring + vessel map
│   │   ├── Chat.tsx               # Full-page chat interface
│   │   ├── Playbooks.tsx          # Playbook management
│   │   ├── Login.tsx              # Authentication page
│   │   └── Settings.tsx           # App settings
│   ├── services/      # API client + data services
│   ├── store/         # Zustand state management
│   ├── context/       # React context (view modes)
│   └── types/         # TypeScript types
└── public/            # Static assets + demo data
```

## Maritime Intelligence

Per-shipment maritime intelligence is calculated when you open a shipment detail page. All data sources are free and require no paid API keys.

| Data Source | What It Provides | Credentials |
|---|---|---|
| **Searoute** | Realistic sea route distance (nm) + ETA calculation | None (pip package) |
| **OFAC SDN List** | US sanctions screening for vessels/entities | None (public CSV) |
| **UN Security Council** | International sanctions screening | None (public XML) |
| **UNCTAD** | Port congestion / turnaround times | None (public data) |
| **Equasis** | Vessel inspections, detentions, deficiencies | Free account at equasis.org |
| **ITU MARS** | MMSI ↔ IMO identity resolution | None (public web) |
| **WTO/WITS** | Tariff rates by country/product (HS codes) | None (public API) |
| **Open Supply Hub** | Factory/supplier locations + ownership | Optional free token |
| **AISStream** | Real-time AIS vessel positions | Free API key at aisstream.io |
| **Open-Meteo** | Weather + marine conditions at any coordinate | None (free API) |

### What gets calculated per shipment:
- **Route distance** — actual nautical miles via sea lanes (not straight line)
- **Port congestion** — turnaround time and congestion ratio for origin + destination ports
- **Sanctions screening** — vessel IMO checked against OFAC + UN lists
- **Vessel registry** — inspection history, detention count, deficiencies, build year → risk score
- **Tariff exposure** — applied tariff rates for the trade route and product category
- **Marine weather** — wind, wave height, and swell at the vessel's live position

## Quickstart

### Option 1: Docker Compose (Recommended)

```bash
cp .env.example .env
# Edit .env with your credentials (see Configuration section)

docker-compose up
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- API docs: http://localhost:8000/docs

### Option 2: Manual Setup

**Prerequisites:** Python 3.11+, Node.js 18+

**Backend:**
```bash
python -m venv .venv

# Windows
.venv\Scripts\activate
# macOS/Linux
source .venv/bin/activate

pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Frontend:**
```bash
cd frontend
npm install
npm run dev
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:8000

## Configuration

Copy `.env.example` to `.env` and configure the required variables:

### Required

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS credentials for Bedrock + SES + DynamoDB |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `AWS_REGION` | AWS region (default: `us-east-1`) |
| `BEDROCK_MODEL_ID` | Bedrock model (default: `us.anthropic.claude-sonnet-4-20250514-v1:0`) |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENAI_API_KEY` | OpenAI API key (alternative LLM) | — |
| `GMAIL_USER` | Gmail for live email ingestion | — |
| `GMAIL_APP_PASSWORD` | Gmail app password | — |
| `AIS_PROVIDER` | AIS provider (`demo`, `aisstream`) | `demo` |
| `AIS_API_KEY` | AISStream API key | — |
| `EQUASIS_USERNAME` | Equasis account email | — |
| `EQUASIS_PASSWORD` | Equasis account password | — |
| `SES_SENDER_EMAIL` | AWS SES verified sender | — |
| `SES_ALERT_RECIPIENTS` | Fallback alert recipients | — |
| `FIREBASE_PROJECT_ID` | Firebase project for auth | — |
| `VITE_API_URL` | Backend URL for frontend | `http://localhost:8000` |

### Vessel Tracking Tuning

| Variable | Description | Default |
|----------|-------------|---------|
| `VESSEL_POLL_INTERVAL_SECONDS` | Position fetch interval | `300` |
| `VESSEL_SILENCE_THRESHOLD_HOURS` | Flag as AIS-silent after | `6` |
| `VESSEL_STALE_THRESHOLD_HOURS` | Show yellow status after | `1` |
| `VESSEL_HISTORY_RETENTION_DAYS` | Auto-purge old positions | `90` |
| `VESSEL_IDENTITY_CACHE_DAYS` | Re-resolve identity after | `30` |

## API Endpoints

### Health
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check |

### Authentication
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/auth/login` | Login and get JWT tokens |
| `POST` | `/auth/refresh` | Refresh access token |

### Ingestion
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/ingest` | Load data, build indexes, run predictive cross-reference |

### Risks
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/risks` | All risk assessments (reactive + predictive) |
| `GET` | `/risks/{id}` | Specific risk details |

### Shipments
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/shipments` | All tracked shipments |
| `POST` | `/shipments/upload-csv` | Upload shipment CSV |
| `POST` | `/shipments/risk-score` | Score a shipment's risk (XGBoost/heuristic) |
| `POST` | `/shipments/risk-advice` | Get Bedrock mitigation advice |
| `POST` | `/shipments/resolution-package` | Full resolution package with financial impact |
| `POST` | `/shipments/preload` | Background preload all shipment analyses |
| `GET` | `/shipments/{id}/preloaded` | Get cached analysis |
| `GET` | `/shipments/risk-summary` | Aggregate risk metrics |

### Maritime Intelligence
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/maritime/route-distance` | Sea route distance + ETA (Searoute) |
| `GET` | `/maritime/route-deviation` | Off-route detection |
| `GET` | `/maritime/vessel-registry/{imo}` | Equasis inspection/detention data |
| `GET` | `/maritime/sanctions/vessel/{imo}` | OFAC + UN vessel sanctions screening |
| `GET` | `/maritime/sanctions/entity/{name}` | Entity sanctions check |
| `GET` | `/maritime/sanctions/route` | Country route sanctions exposure |
| `GET` | `/maritime/tariffs` | WTO/WITS tariff rates |
| `GET` | `/maritime/port-congestion/{port}` | Single port congestion status |
| `GET` | `/maritime/port-congestion` | All congested ports |
| `GET` | `/maritime/supply-hub/search` | Open Supply Hub facility search |
| `GET` | `/maritime/identity/resolve-mmsi/{mmsi}` | ITU MARS MMSI→IMO resolution |

### Vessel Tracking
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/vessels/watchlist` | All tracked vessels with status |
| `GET` | `/vessels/fleet-status` | Fleet summary (active/stale/silent) |
| `GET` | `/vessels/danger-zones` | Danger zone definitions + vessels inside |
| `GET` | `/vessels/search?q=...` | Search vessels by name |
| `GET` | `/vessels/resolve/{imo}` | Resolve IMO to full vessel identity |
| `GET` | `/vessels/{imo}/status` | Real-time vessel status |
| `GET` | `/vessels/{imo}/track` | Historical position track |
| `POST` | `/vessels/watchlist/reload` | Force reload watchlist CSV |
| `POST` | `/vessels/{imo}/link` | Link vessel to supplier/shipment |
| `GET` | `/vessels/{imo_number}` | Vessel telemetry by IMO (legacy) |

### Agents
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/agents/strands/shipment-risk` | Run Strands-orchestrated risk workflow |
| `GET` | `/agents/strands/status` | Check Strands SDK availability |

### Network / Digital Twin
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/network` | Full supply chain graph |
| `GET` | `/node/{id}` | Node details |
| `GET` | `/node/{id}/context` | Full enriched node context |
| `GET` | `/node/{id}/impact` | Upstream/downstream impact analysis |
| `POST` | `/graph/propagate` | Trigger risk propagation |
| `POST` | `/graph/score-nodes` | Score nodes using live intelligence |

### Chat
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/chat` | Query AI advisor (Bedrock-powered) |
| `GET` | `/chat/context` | Current advisor knowledge state |

### Playbooks
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/playbooks` | List playbook definitions |
| `GET` | `/playbooks/executions` | List triggered executions |
| `PATCH` | `/playbooks/{id}` | Toggle playbook enabled/disabled |
| `POST` | `/playbooks/{id}/simulate` | Simulate a playbook execution |
| `POST` | `/playbooks/executions/{id}/feedback` | Submit accept/reject feedback |

### Weather
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/weather/route` | Weather along a route |
| `GET` | `/weather/position` | Weather + marine at a point |

### Email Alerts
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/email/send` | Send custom email via AWS SES |
| `POST` | `/email/risk-alert` | Send role-routed risk alert |
| `GET` | `/email/routing-rules` | View email routing configuration |

### Feedback
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/feedback/stats` | Feedback statistics |
| `GET` | `/feedback/history` | Feedback history |

### WebSocket
| Method | Path | Description |
|--------|------|-------------|
| `WS` | `/ws/{subscription}` | Real-time updates (risks, network, alerts, all) |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | FastAPI, Python 3.11+, Uvicorn |
| AI/LLM | Amazon Bedrock (Claude), OpenAI (optional) |
| Agent Framework | Strands Agents SDK |
| Risk Scoring | XGBoost + deterministic heuristics |
| Frontend | React 18, TypeScript, Vite |
| Styling | TailwindCSS |
| State Management | Zustand, React Query |
| Maps | Leaflet, React-Leaflet |
| Graph Visualization | React Flow |
| Charts | Recharts |
| Auth | JWT + Firebase Admin SDK |
| Search | TF-IDF + cosine similarity |
| Maritime | Searoute, OFAC, UN Sanctions, UNCTAD, Equasis, WTO/WITS |
| Vessel Tracking | AISStream (WebSocket), demo provider |
| Real-time | WebSockets |
| Email | AWS SES (role-based routing) |
| Database | DynamoDB (production), SQLite (local caches) |
| Deployment | Docker, AWS ECS Fargate |

## Background Workers

The backend runs several background workers on startup:

| Worker | Interval | Purpose |
|--------|----------|---------|
| Ingestion | 15 min | Refresh data from all sources |
| Risk | 30 min | Re-evaluate risk assessments |
| Propagation | 1 min | Propagate risk through the digital twin graph |
| Vessel Tracking | Configurable | Poll AIS positions for watchlist vessels |

## Testing

```bash
pytest tests/
```

## Deployment

See [`deploy/DEPLOYMENT_GUIDE.md`](deploy/DEPLOYMENT_GUIDE.md) for full ECS Fargate deployment instructions.

### Quick Deploy (Docker)

```bash
# Build and push to ECR
docker build -t supply-chain-advisor .
docker tag supply-chain-advisor:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/supply-chain-advisor:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/supply-chain-advisor:latest

# Redeploy ECS service
aws ecs update-service \
  --cluster supply-chain-cluster \
  --service supply-chain-service \
  --force-new-deployment \
  --region us-east-1
```

### Production Architecture

| Component | Service |
|-----------|---------|
| Backend | AWS ECS Fargate |
| Frontend | Nginx container on ECS (or Vercel/Netlify) |
| Load Balancer | AWS ALB with HTTPS |
| Secrets | AWS Secrets Manager |
| Database | DynamoDB |
| AI | Amazon Bedrock |
| Email | AWS SES |
| Auth | Firebase |
| Logs | CloudWatch |

## License

MIT
