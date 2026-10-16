# 08. Application Backup and Disaster Recovery

![architecture](docs/architecture.png)

**PostgreSQL - S3 - Encryption** | *Phase 5 - Production readiness* | `lab` - verify before production use.

> PostgreSQL to encrypted S3/Spaces backups with automation, restore tests, and documented RPO/RTO.

## Architecture

```mermaid
flowchart LR
  PG[(Postgres)] --> Dump --> Enc[Encrypt] --> S3[(S3)] --> Restore
```

Full diagram: [docs/architecture.png](docs/architecture.png) - Design: [docs/architecture.md](docs/architecture.md)

## Structure

```
.
+-- app/
+-- terraform/ or infrastructure/
+-- monitoring/
+-- tests/
+-- runbooks/
+-- docs/architecture.md, architecture.png, cost-estimate.md
+-- .github/workflows/
```

## Quickstart (lab)

```bash
git clone https://github.com/navin-kumar10/app-backup-disaster-recovery.git
cd app-backup-disaster-recovery
make validate
make plan
make apply
make smoke
make destroy
```

See [runbooks/DEPLOYMENT.md](runbooks/DEPLOYMENT.md), [runbooks/ROLLBACK.md](runbooks/ROLLBACK.md), [docs/cost-estimate.md](docs/cost-estimate.md).

## Implementation order

10-project portfolio. Order: Phase 1 (04,07,09) -> Phase 2 (03,04,05) -> Phase 3 (01) -> Phase 4 (02) -> Phase 5 (08,09,10).

## License

MIT - see LICENSE.
