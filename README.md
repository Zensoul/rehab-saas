# Rehab SaaS — monorepo scaffold

This repository contains the monorepo scaffold for the Rehab SaaS project.

## Structure
- `apps/frontend` — Next.js React frontend
- `services/api` — API Lambdas / handlers
- `services/workers` — background workers (SQS consumers)
- `ai/ml` — ML experiments and training code
- `infra/terraform` — Terraform infra
- `packages/shared-types` — shared TypeScript/Zod types

## Day 1 deliverables
- pnpm workspace
- editorconfig, prettier config
- repo folder structure
- GitHub Actions PR CI skeleton

## How to start (developer)
1. Install pnpm: https://pnpm.io/installation
2. Install root deps: `pnpm install`
3. Open in VSCode

## Contributing
Create feature branches, open PRs into `main`. PRs should pass CI checks (lint & tests) before merge.
