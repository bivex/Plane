# Plane - Self-Hosted Setup for macOS

Docker-based self-hosted setup for [Plane](https://plane.so) project management tool with automatic configuration.

## Quick Start

```bash
docker-compose up -d
```

Wait ~30 seconds, then open: **http://localhost/**

## Default Credentials

| Field    | Value              |
|----------|-------------------|
| Email    | admin@plane.local |
| Password | admin123          |

## Configuration

Edit `.env` to customize before first run:

```env
PLANE_PORT=80

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
                    │   Browser :80   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  plane-proxy    │
                    │  (nginx)        │
                    └────────┬────────┘
                             │
           ┌─────────────────┼─────────────────┐
           │                 │                 │
   ┌───────▼───────┐ ┌───────▼───────┐ ┌───────▼───────┐
   │  plane-web    │ │  plane-api    │ │   /api/       │
   │  (Next.js)    │ │  (Django)     │ │   /auth/      │
   │  :3000        │ │  :8000        │ │               │
   └───────────────┘ └───────┬───────┘ └───────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
┌───────▼───────┐    ┌───────▼───────┐    ┌───────▼───────┐
│  plane-db     │    │  plane-redis  │    │  plane-minio  │
│  (PostgreSQL) │    │  (Valkey)     │    │  (S3 Storage) │
│  :5432        │    │  :6379        │    │  :9000        │
└───────────────┘    └───────────────┘    └───────────────┘
```

## Services

| Service      | Port  | Description              |
|--------------|-------|--------------------------|
| plane-proxy  | 80    | Nginx reverse proxy      |
| plane-web    | 3000* | Next.js frontend         |
| plane-api    | 8000* | Django REST API          |
| plane-db     | 5432  | PostgreSQL database      |
| plane-redis  | 6379  | Valkey/Redis cache       |
| plane-mq     | 5672  | RabbitMQ message queue   |
| plane-minio  | 9000  | MinIO object storage     |

*Internal only - access via nginx proxy on port 80

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
curl http://localhost/api/instances/
```

## System Requirements

- Docker Desktop for Mac/Windows or Docker Engine for Linux
- 4GB+ RAM (8GB recommended)
- 10GB+ free disk space
- Ports 80, 5432, 6379, 9000 available

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
