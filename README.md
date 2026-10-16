# 08. Application Backup and Disaster Recovery

![architecture](docs/architecture.png)

**PostgreSQL · S3 · Encryption** · *Phase 5 — Production readiness* · `lab`.

> Encrypted Postgres → S3/Spaces backups, checksum, lifecycle, automated restore test, RPO/RTO report. Prove recovery, not just backup.

## Contents

1. Outcomes 2. Architecture 3. Prerequisites 4. Repo map 5. Step 0 clone 6. Step 1 local Postgres + dump 7. Step 2 encrypt + upload 8. Step 3 Terraform bucket 9. Step 4 scheduled + retention 10. Step 5 restore drill + RPO/RTO 11. CI 12. Teardown 13. Troubleshooting

## 1. Outcomes

- `app/backup.sh` dumps, gzips, names `backup-YYYY-MM-DD.sql.gz`, checksums.
- `app/restore.sh` gunzips into `$DATABASE_URL`, verifies row counts.
- `terraform/main.tf` bucket + lifecycle; `monitoring/rpo-report.md` evidence template.

## 2. Architecture

```mermaid
flowchart LR
  PG[(Postgres)] --> Dump[pg_dump cron/CronJob]
  Dump --> Enc[Encrypt + checksum]
  Enc --> S3[(S3 versioned + lifecycle)]
  S3 --> Restore[Staging restore verify]
```

## 3. Prerequisites

- docker, psql client (`brew install postgresql`), awscli or `s3cmd`, gzip, age/gpg optional.
- No cloud for Steps 0–1 (local Postgres container).

## 4. Repository map

```
app/backup.sh    # pg_dump | gzip
app/restore.sh   # gunzip | psql
terraform/main.tf# lab-backups bucket
monitoring/rpo-report.md
```

## Step 0 — Clone

```bash
git clone https://github.com/navin-kumar10/app-backup-disaster-recovery.git
cd app-backup-disaster-recovery
bash tests/smoke.sh
cat app/backup.sh app/restore.sh terraform/main.tf
chmod +x app/*.sh
```

## Step 1 — Local Postgres and seed

```bash
docker run -d --name pg-lab -e POSTGRES_PASSWORD=labpass -e POSTGRES_DB=labdb -p 5432:5432 postgres:16
sleep 5
export DATABASE_URL="postgres://postgres:labpass@localhost:5432/labdb"
psql "$DATABASE_URL" -c "create table if not exists tasks(id serial primary key, title text); insert into tasks(title) values ('drill-1');"
psql "$DATABASE_URL" -c "select count(*) from tasks;"
```

## Step 2 — Backup and inspect

```bash
./app/backup.sh
ls -lh backup-*.sql.gz
gzip -dc backup-*.sql.gz | head -20
sha256sum backup-*.sql.gz > backup.sha256 && cat backup.sha256
```

Add encryption (prod): `pg_dump "$DATABASE_URL" | gzip | age -r AGE-RECIPIENT -o backup-$(date +%F).sql.gz.age`.

## Step 3 — Bucket via Terraform

```bash
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
aws s3 cp backup-*.sql.gz s3://lab-backups/ --dryrun
aws s3 cp backup-*.sql.gz s3://lab-backups/
aws s3 ls s3://lab-backups/
```

Enable in console/TF: Versioning + SSE-KMS + lifecycle (30d Standard → IA → Glacier) + replication optional.

## Step 4 — Schedule

Cron (VM): `crontab -e` → `0 2 * * * /opt/lab/app/backup.sh >> /var/log/pg-backup.log 2>&1`.
K8s CronJob: wrap `backup.sh` in image, mount `DATABASE_URL` from secret, `successfulJobsHistoryLimit: 3`.

## Step 5 — Restore drill (the grade)

```bash
createdb labdb_restore 2>/dev/null || true
export RESTORE_URL="postgres://postgres:labpass@localhost:5432/labdb_restore"
DATABASE_URL="$RESTORE_URL" ./app/restore.sh backup-*.sql.gz
psql "$RESTORE_URL" -c "select count(*) from tasks;"
# fill monitoring/rpo-report.md: backup time, size, checksum, restore minutes, RPO/RTO achieved
cat monitoring/rpo-report.md
```

Pass = row counts match + app boots on restored DB. Do this monthly; record evidence.

## CI

- Shellcheck `backup.sh/restore.sh`, `terraform validate`, dry-run restore on ephemeral Postgres service in Actions.

## Teardown

```bash
docker stop pg-lab && docker rm pg-lab
rm -f backup-*.sql.gz backup.sha256
terraform -chdir=terraform destroy
```

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `pg_dump: connection refused` | DB down/URL wrong | `docker ps`, `echo $DATABASE_URL` |
| `AccessDenied` S3 | IAM/creds | `aws sts get-caller-identity`, bucket policy |
| Restore empty | wrong file/DB | `gzip -dc file | head`, check target DB name |

No backup without tested restore. MIT — LICENSE.
