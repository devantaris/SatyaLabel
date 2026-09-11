# Production Deployment Guide

This guide deploys the full SatyaLabel stack — API, Celery worker, PostGIS,
Redis, nginx — on a single Linux server using `docker-compose.prod.yml`.

For local development use `docker-compose.yml` (dev) instead — see the
[backend README](../satyalabel_backend/README.md).

## 1. Prerequisites

- A Linux server (2 vCPU / 4 GB RAM minimum; EasyOCR fallback is CPU-hungry —
  4 vCPU recommended) with Docker Engine + the compose plugin
- A domain name pointing at the server (for TLS) — optional for testing
- Ports 80/443 open

## 2. Configure secrets

```bash
cd satyalabel_backend
cp .env.prod.example .env.prod
openssl rand -hex 32        # paste into SECRET_KEY
```

Edit `.env.prod`: set `SECRET_KEY`, `POSTGRES_PASSWORD`, `ALLOWED_ORIGINS`
(your frontend origins). The app **refuses to start** in production with the
default SECRET_KEY.

## 3. Start the stack

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build
```

The `api` service runs `alembic upgrade head` automatically before starting
uvicorn (2 workers). Verify:

```bash
curl http://localhost/health          # via nginx
docker compose --env-file .env.prod -f docker-compose.prod.yml ps
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f api
```

## 4. Seed the first admin (once)

```bash
# Set BOOTSTRAP_ADMIN_EMAIL / BOOTSTRAP_ADMIN_PASSWORD in .env.prod and
# restart, then register the admin:
curl -X POST http://localhost/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@gov.in","password":"strong-pass-123","role":"admin",
       "bootstrap_admin_email":"admin@gov.in",
       "bootstrap_admin_password":"<bootstrap password>"}'
# Then REMOVE the bootstrap vars from .env.prod and restart.
```

## 5. TLS

`deploy/nginx.conf` ships HTTP-only. To enable HTTPS:

```bash
# Install certbot, then:
sudo mkdir -p /var/www/certbot deploy/certs
sudo certbot certonly --webroot -w /var/www/certbot -d api.yourdomain.in
sudo cp /etc/letsencrypt/live/api.yourdomain.in/{fullchain,privkey}.pem deploy/certs/
```

Then in `docker-compose.prod.yml` uncomment the 443 port and certs mount, and
in `deploy/nginx.conf` uncomment the HTTPS server blocks. Reload:

```bash
docker compose --env-file .env.prod -f docker-compose.prod.yml restart nginx
```

Alternatively, terminate TLS at a cloud load balancer and leave nginx as-is.

## 6. Image storage

By default images live on the shared `uploads_data` volume and are served by
FastAPI at `/uploads/...`. For scale/durability switch to S3-compatible
storage:

1. Add `boto3` to the image: change the Dockerfile.prod pip line to
   `pip install --no-cache-dir ".[s3]"`
2. Set in `.env.prod`:
   - `STORAGE_BACKEND=s3`
   - `S3_BUCKET=...`, `S3_ENDPOINT_URL=...` (MinIO etc.)
   - `S3_PUBLIC_URL_BASE=...` for public buckets/CDN, or leave unset for
     presigned URLs (`S3_PRESIGN_EXPIRE_SECONDS`, default 1 h)
3. AWS credentials via the standard boto3 chain (env vars or IAM role)

## 7. Operations

```bash
# Update to a new release
git pull && docker compose --env-file .env.prod -f docker-compose.prod.yml up -d --build

# Backup the database
docker compose --env-file .env.prod -f docker-compose.prod.yml exec db \
  pg_dump -U satyalabel satyalabel | gzip > backup_$(date +%F).sql.gz

# Restore
gunzip -c backup_YYYY-MM-DD.sql.gz | \
  docker compose --env-file .env.prod -f docker-compose.prod.yml exec -T db psql -U satyalabel satyalabel

# Tail structured logs (12-factor: everything to stdout/stderr)
docker compose --env-file .env.prod -f docker-compose.prod.yml logs -f --tail=100
```

## 8. Mobile app configuration

Build the Flutter app pointing at the deployed backend (see
`satyalabel_frontend/README.md`): set the backend URL in-app to
`https://api.yourdomain.in`. For release builds remove
`android:usesCleartextTraffic` from the Android manifest and the
`NSAllowsArbitraryLoads` key from the iOS Info.plist (HTTP-only dev
exceptions) once TLS is active.

## Security checklist

- [ ] Strong `SECRET_KEY` (startup-enforced)
- [ ] Strong `POSTGRES_PASSWORD`; db not exposed on the host
- [ ] TLS active (certbot or cloud LB)
- [ ] `ALLOWED_ORIGINS` restricted to real frontend origins
- [ ] Bootstrap admin vars removed after first admin registration
- [ ] Regular `pg_dump` backups (cron)
