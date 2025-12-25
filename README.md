# Plane - Self-Hosted Setup for macOS

Docker-based self-hosted setup for [Plane](https://plane.so) project management tool with automatic configuration.

## Quick Start

```bash
docker-compose up -d
```

Wait ~30 seconds, then open: **http://localhost:33333/**

## Default Credentials

| Field    | Value              |
|----------|-------------------|
| Email    | admin@plane.local |
| Password | admin123          |

## Configuration

Edit `.env` to customize before first run:

```env
# Web interface port
PLANE_PORT=33333

# Admin credentials (used on first setup only)
ADMIN_EMAIL=admin@plane.local
ADMIN_PASSWORD=admin123
```

## Commands

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f plane-api
docker-compose logs -f plane-web

# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart plane-api

# Full reset (WARNING: deletes all data!)
docker-compose down -v
docker-compose up -d
```

## Architecture

```
                      ┌─────────────────┐
                      │ Browser :33333  │
                      └────────┬────────┘
                               │
                      ┌────────▼────────┐
                      │  plane-proxy    │
                      │  (nginx)        │
                      └────────┬────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
      ┌───────▼───────┐ ┌──────▼──────┐ ┌───────▼───────┐
      │  plane-web    │ │  plane-api  │ │  plane-worker │
      │  (Next.js)    │ │  (Django)   │ │  (Celery)     │
      └───────────────┘ └──────┬──────┘ └───────────────┘
                               │
       ┌───────────┬───────────┼───────────┬───────────┐
       │           │           │           │           │
┌──────▼──────┐ ┌──▼───┐ ┌─────▼─────┐ ┌───▼───┐ ┌─────▼─────┐
│  plane-db   │ │redis │ │ plane-mq  │ │ minio │ │  init     │
│ (PostgreSQL)│ │      │ │ (RabbitMQ)│ │ (S3)  │ │ (setup)   │
└─────────────┘ └──────┘ └───────────┘ └───────┘ └───────────┘
```

## Services

| Service      | Port     | Description              |
|--------------|----------|--------------------------|
| plane-proxy  | 33333    | Nginx reverse proxy      |
| plane-web    | internal | Next.js frontend         |
| plane-api    | internal | Django REST API          |
| plane-db     | dynamic  | PostgreSQL database      |
| plane-redis  | dynamic  | Valkey/Redis cache       |
| plane-mq     | dynamic  | RabbitMQ message queue   |
| plane-minio  | dynamic  | MinIO object storage     |

Internal services use dynamic ports to avoid conflicts.

```bash
# View assigned ports
docker-compose ps
```

## Files

```
.
├── docker-compose.yml       # Main Docker Compose configuration
├── .env                     # Environment variables
├── nginx.conf               # Nginx reverse proxy config
├── plane-web-entrypoint.sh  # Frontend startup script
├── plane-init.sh            # Automatic setup script
├── install-plane-mac.sh     # Installation helper script
└── README.md                # This documentation
```

## Troubleshooting

### 502 Bad Gateway
```bash
docker-compose restart plane-proxy
```

### API not responding
```bash
docker-compose restart plane-api
```

### Clear application cache
```bash
docker exec plane-plane-api-1 python manage.py clear_cache
docker-compose restart plane-api
```

### Reset admin password
```bash
docker exec -it plane-plane-api-1 python manage.py changepassword admin@plane.local
```

### Check service status
```bash
docker-compose ps
```

### Check service health
```bash
curl http://localhost:33333/api/instances/
```

## System Requirements

- Docker Desktop for Mac/Windows or Docker Engine for Linux
- 4GB+ RAM (8GB recommended)
- 10GB+ free disk space

## Updating

```bash
# Pull latest images
docker-compose pull

# Recreate containers
docker-compose up -d
```

## Backup

### Database backup
```bash
docker exec plane-plane-db-1 pg_dump -U plane plane > backup.sql
```

### Database restore
```bash
cat backup.sql | docker exec -i plane-plane-db-1 psql -U plane plane
```

## License

Plane is licensed under [AGPL-3.0](https://github.com/makeplane/plane/blob/master/LICENSE).

## Links

- [Plane Website](https://plane.so)
- [Plane GitHub](https://github.com/makeplane/plane)
- [Plane Documentation](https://docs.plane.so)
