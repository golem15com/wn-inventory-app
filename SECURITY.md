# Security Policy

Inventory is an authentication-bearing, self-hostable application: it issues JWTs and
personal API tokens, stores bring-your-own-key (BYOK) AI credentials, and enforces
per-Area permission scoping. We take security reports seriously and appreciate
responsible disclosure.

## Reporting a Vulnerability

**Please report security vulnerabilities privately through GitHub Private Vulnerability
Reporting.**

1. Go to this repository's **Security** tab.
2. Click **"Report a vulnerability"**.
3. Fill in the advisory form with as much detail as you can (affected component,
   reproduction steps, impact, and any proof-of-concept).

Reports submitted this way are **private and confidential** — only the maintainers can
see them, and the discussion stays inside a draft security advisory until a fix is ready.

**Please do not** open a public GitHub issue, pull request, or discussion for a security
problem, as that would disclose the vulnerability before it can be addressed.

There is no email channel, no bug-bounty program, and no formal SLA — this is a small,
self-hosted, open-source project, and Private Vulnerability Reporting is the single
intended channel for confidential reports.

## Supported Versions

| Version          | Supported          |
| ---------------- | ------------------ |
| v1.x             | :white_check_mark: |
| older (pre-public) | :x:              |

Only the current `v1.x` line is supported. Pre-public history is not maintained and
receives no security fixes.

## Response Expectations

We aim to **acknowledge a report within a few business days** and to keep you updated as
we investigate and prepare a fix. Because this is a small project maintained on a
best-effort basis, please understand that timelines for a full remediation may vary — we
do not commit to a fixed SLA. We will credit reporters who wish to be acknowledged once a
fix has shipped.

## In Scope

The following surfaces reflect the application's real authentication-bearing attack
surface and are in scope for a vulnerability report:

- **JWT API authentication** (`/_user`, `/_inventory` API) — token forgery, signature or
  expiry bypass, refresh-flow weaknesses, or any way to authenticate as another user.
- **Personal API tokens** (`inv_…`, SHA-256-at-rest, scope-gated `read` / `write` / `ai`)
  — token leakage, scope escalation, or bypass of the JWT-vs-token mutual-exclusion gate.
- **BYOK AI credentials** (stored with an `encrypted` cast and `$hidden` from API output,
  both per-user and organisation-shared) — exfiltration of a stored key through any API
  response, and **SSRF** via a user-supplied AI `base_url`.
- **Per-Area permission scoping** (`accessibleBy`, with deliberate 404-not-403 no-leak
  responses) — any cross-Area or cross-organisation data exposure, including through
  search results.
- **Organisation-shared keys and first-run onboarding** (zero-user bootstrap) — privilege
  escalation between organisation members, or replay/abuse of the onboarding bootstrap.

## Out of Scope

The following are **not** considered vulnerabilities in this project:

- **Self-host misconfiguration** — issues caused by the operator's own deployment, such as
  a misconfigured `.env`, an open reverse proxy, an internet-exposed Typesense instance,
  or weak server credentials. Securing the host environment is the operator's
  responsibility.
- **Third-party AI provider issues** — behaviour, billing, or vulnerabilities of OpenAI,
  Anthropic, or any other upstream provider whose key you supply.
- **Social engineering** — phishing or other attacks targeting maintainers or users.
- **Denial of service** — volumetric or resource-exhaustion attacks against a self-hosted
  instance.

Thank you for helping keep Inventory and its users safe.
