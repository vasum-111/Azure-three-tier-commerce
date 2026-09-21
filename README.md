# Fieldwork · Three-Tier E-Commerce Architecture

[![Validate](https://github.com/vasum-111/azure-three-tier-commerce/actions/workflows/ci.yml/badge.svg)](https://github.com/vasum-111/azure-three-tier-commerce/actions/workflows/ci.yml)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

A compact commerce demo that connects presentation, application and data tiers using Azure services.

**[Open browser preview](https://vasum-111.github.io/azure-three-tier-commerce/)** · **[Deployment guide](DEPLOYMENT.md)** · **[Operations & tradeoffs](OPERATIONS.md)**

> **Deployment status:** the public browser preview is static hosting on GitHub Pages. It uses sample data and does not call an Azure backend. Azure resources have **not** been provisioned; cloud deployment awaits subscription access and cost approval. Bicep compilation and local tests are validation, not evidence of a successful Azure deployment.

## What this demonstrates

- Original storefront, shopping cart and demo checkout; no payments or personal data collection.
- Server-authoritative prices, quantity validation and idempotency keys for safe retries.
- SQL product/order persistence, a disposable Redis catalog cache and Blob product artwork.
- Private endpoints and DNS for the data tier; workload identity for Storage.
- Separate browser-only, local-memory and Azure-backed execution modes.

## Architecture

~~~mermaid
flowchart LR
    Browser -->|HTTPS| Edge[Front Door Premium + WAF]
    Edge -->|Private Link / HTTP| LB[Internal load balancer]
    LB --> App[AKS / web and API]
    App -->|TLS / private endpoint| SQL[Azure SQL / products + orders]
    App -->|TLS / private endpoint| Redis[Azure Managed Redis / catalog cache]
    App -->|HTTPS / workload identity| Blob[Private Blob Storage / product images]
    Actions[GitHub Actions / OIDC] --> ACR[Container Registry]
    ACR --> App
~~~

The three logical tiers are the browser UI, the Node.js application on AKS, and SQL/Redis/Blob data services. The web assets and API share one deployment to keep the learning environment small. Front Door terminates public TLS; the current private origin hop uses HTTP. See the production limitations before using real customer data.

## Run locally

Prerequisite: Node.js 24 LTS and npm.

~~~bash
git clone https://github.com/vasum-111/azure-three-tier-commerce.git
cd azure-three-tier-commerce
npm ci
npm test
npm start
~~~

Open **http://localhost:8080**. Local mode keeps orders in process memory and resets them on restart; Azure mode uses SQL.

## API contract

| Method | Route | Behavior |
|---|---|---|
| GET | /api/products | Catalog with integer USD cents |
| GET | /api/products/:id | Product or 404 |
| GET | /healthz | Process liveness |
| GET | /readyz | Data-store readiness |
| GET | /api/images/:name.svg | Product artwork from Blob in Azure mode |
| POST | /api/orders | Validated demo order; requires Idempotency-Key |

~~~bash
curl -X POST http://localhost:8080/api/orders \
  -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: demo-order-00000001' \
  -d '{"items":[{"id":"desk-lamp","quantity":2}]}'
~~~

Client-supplied prices are ignored. Replaying the same key/cart returns the same order; a changed cart returns 409. Requests over 16 KiB, unknown products and invalid quantities are rejected.

## Repository map

| Path | Purpose |
|---|---|
| web/ | Original website and interactive UI |
| docs/ | GitHub Pages preview; sample mode enabled |
| infra/ | Bicep resource definitions |
| scripts/ | Explicit deployment helpers |
| src/ | Application and data adapters |
| k8s/ | Deployment, service, probes and policies |
| test/ | Automated checks |
| .github/workflows/ | Continuous validation and gated Azure release |

## Validation and limitations

See [VALIDATION.md](VALIDATION.md) for tested behavior and unverified cloud steps. This is a learning/portfolio project, not a production certification. It intentionally omits payments, login, inventory reservation and customer data.

## Specification and attribution

Built from the three-project scope supplied by the user from the **Azure Services Crash Course**. The original PDF attachment was unavailable in this task, so its exact text and resource links could not be checked. The user-provided project names/services are the scope of record. Application code, layout, artwork and project structure are original; no third-party repository was copied. Microsoft documentation informed service configuration. See [REFERENCES.md](REFERENCES.md). MIT license covers this repository; dependencies retain their own licenses.
