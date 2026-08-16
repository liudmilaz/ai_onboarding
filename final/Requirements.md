# SaaS Analytics Platform
## AI-Assisted Development Training Project

### Project Overview

Build a complete end-to-end analytics platform for **Invented Software**, a fictional B2B SaaS company selling business-management software to small merchants — using AI-assisted development practices. This project simulates real-world data engineering and business intelligence workflows while teaching modern development practices with AI tooling.

The company's revenue model is **subscription-only**: recurring monthly fees on software plans and add-ons. There is no transaction processing, no interchange, and no hardware — every euro of revenue is recurring, which makes the SaaS metric stack the natural analytical frame.

**Dataset Location**: the `saas/` directory contains 6 CSV tables: merchants, subscriptions, products, markets, acquisition costs, and operating costs. Two years of data (2024–2025), 8 markets, 160 merchants, 117 subscription records.

**Data conventions**: all money is stored in **minor units** (cents) — `price_eur = 1900` means €19.00. `mrr_local` and `spend_amount` are in **local currency** and must be converted via `raw_markets.eur_fx` (`amount_eur = amount_local * eur_fx`); operating costs are already in EUR.

### Learning Objectives

By completing this project, you will demonstrate proficiency in:
- AI-assisted research and technology selection
- Database design and implementation
- Data modeling with dbt
- Learn about basic of containers, as setup should be containerized with Docker Compose
- Business intelligence platform setup and configuration
- End-to-end data pipeline orchestration
- Technical documentation and presentation skills

### Project Phases

#### Phase 1: Data Discovery & Business Understanding
**Deliverable**: Business requirements document

**⚡ FIRST STEP**: Run `/init` to seed an initial CLAUDE.md if you're starting fresh elsewhere, then `git init` and a first commit so you have an undo history. Per-phase feature branches are optional — useful practice, not required for solo work.

**Skills**: `/brainstorming` to refine the business questions before you document them.

- Analyze the provided dataset structure and relationships
- Document business logic and key performance indicators
- Identify analytical questions the platform should answer
- Define success metrics for the analytics platform

#### Phase 2: Architecture & Technology Research
**Deliverable**: Technical architecture document with AI research logs

- Research and select appropriate database technology (PostgreSQL, MySQL, SQLite, etc.)
- Research and select business intelligence platform (Lightdash, Grafana, Metabase, Apache Superset, etc.)
- For each tool on your shortlist, check whether a public Claude Code skill, plugin, or MCP server exists for it (`/plugins`, marketplace, web search). A tool with mature skill support has a much shorter learning curve. Document discoveries in the ADR.
- Document technology choices with AI-assisted research rationale
- Create system architecture diagram

**Skills**: `/brainstorming` for tool trade-offs, then `/writing-plans` for the setup plan.

#### Phase 3: Database Implementation
**Deliverable**: Functional database with imported data

- Install and configure chosen database system
- Design and implement database schema
- Import CSV data with data quality validation
- Create database documentation

**Skills**: `/executing-plans` to work the Phase 2 plan; `/systematic-debugging` when things break.

#### Phase 4: Data Modeling with dbt
**Deliverable**: dbt project with analytical models

- Initialize dbt project and configure database connection
- Develop staging models for raw data cleaning
- Build dimensional models for analytical use cases
- Implement data quality tests and documentation
- Generate and review dbt docs

**Skills**: `/test-driven-development` for dbt test design; `/executing-plans` for staging → marts work.

#### Phase 5: Business Intelligence Platform (3-4 hours)
**Deliverable**: Configured BI platform with dashboards

- Install and configure chosen BI platform
- Connect BI platform to analytical database models
- Design and build executive dashboard with key metrics
- Create detailed operational reports
- Implement user access and security

**Skills**: `/executing-plans` for setup; `/requesting-code-review` once dashboards are wired up.

#### Phase 6: System Integration & Automation
**Deliverable**: Automated deployment scripts

- Create startup scripts for all services
- Implement data refresh functionality with validation
- Build error handling and monitoring
- Create user documentation for system operation

**Skills**: `/finishing-a-development-branch` when wrapping up; `/claude-automation-recommender` as a meta-exercise on the finished repo.

### Technical Requirements

**Version Control Setup**:
- Initialize a local git repository at project start (no remote publishing required)
- Use git to track decision evolution and maintain project history
- Per-phase feature branches (`phase-1-discovery`, `phase-2-architecture`, etc.) are recommended practice but optional for solo work — commits on `main` are fine if branches feel like overhead

**Architecture Constraints**:
- Open source technology stack only
- Local deployment (no cloud SaaS solutions)
- Containerize the entire stack with Docker Compose
- Production-ready configuration
- Scalable design patterns

**Functional Requirements**:
- One-command service startup (`./start.sh` or equivalent)
- Data refresh capability with schema validation
- Automated error handling and logging
- Mobile-responsive dashboard design

**Performance Requirements**:
- Dashboard load times under 3 seconds
- Data refresh completion under 1 minute
- Support for concurrent users (simulated)

### Bonus Challenges

#### Advanced Analytics (Optional)
- Implement customer segmentation analysis
- Add predictive analytics for sales forecasting
- Create cohort analysis for customer retention
- Build real-time alerting for key metrics

#### DevOps & Automation (Optional)
- Implement CI/CD pipeline for dbt models
- Add automated testing for dashboard functionality
- Create backup and recovery procedures
- Run `/claude-automation-recommender` on the finished repo and propose two Claude Code automations (hook, subagent, or custom skill) that would improve the project workflow

#### Advanced Visualizations (Optional)
- Interactive drill-down capabilities
- Custom KPI widgets
- Embedded analytics in mock web application
- Mobile-first dashboard design

### Final Deliverables

#### 1. Technical Documentation Package
- Architecture decision record (ADR) for all technology choices
- Database schema documentation
- dbt model documentation (auto-generated)
- BI platform configuration guide
- System operation manual

#### 2. Live Demonstration (20 minutes)
- System startup demonstration
- Dashboard walkthrough with business insights
- Data refresh process demo
- Q&A session on technical decisions

#### 3. AI Development Process Report
- Log of AI interactions and research queries
- Documentation of how AI assisted in each phase
- Log of which Claude Code skills you invoked, when, and which paid off most
- Reflection on AI-assisted vs traditional development approaches
- Recommendations for future AI-assisted projects

### Success Criteria

**Technical Excellence**:
- All services start successfully with single command
- Data pipeline processes without errors
- Dashboard loads and displays accurate data
- System handles data schema changes gracefully

**Business Value**:
- Dashboard answers key business questions
- Insights are actionable and clearly presented
- Data storytelling effectively communicates findings

**Professional Development**:
- Clear documentation of all technical decisions
- Confident presentation of system capabilities
- Demonstrated understanding of AI-assisted development workflows