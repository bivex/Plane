#!/bin/bash
set -e

echo "=== Plane Auto-Setup ==="

# Configuration
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@plane.local}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin123}"

echo "Waiting for database..."
python manage.py wait_for_db

echo "Running migrations..."
python manage.py migrate --noinput

echo "Creating MinIO bucket..."
python manage.py create_bucket || echo "Bucket may already exist"

echo "Creating admin user: $ADMIN_EMAIL"

# Create superuser using createsuperuser with environment variables
export DJANGO_SUPERUSER_EMAIL="$ADMIN_EMAIL"
export DJANGO_SUPERUSER_USERNAME="$ADMIN_EMAIL"
export DJANGO_SUPERUSER_PASSWORD="$ADMIN_PASSWORD"

python manage.py createsuperuser --noinput 2>/dev/null || echo "Admin user may already exist"

# Create or update instance and mark as setup done
python manage.py shell -c "
from plane.license.models import Instance
from django.utils import timezone
import uuid

i = Instance.objects.first()
if i:
    i.is_setup_done = True
    i.is_signup_screen_visited = True
    i.save()
    print('Instance setup marked as complete')
else:
    Instance.objects.create(
        instance_id=uuid.uuid4(),
        is_setup_done=True,
        is_signup_screen_visited=True,
        last_checked_at=timezone.now()
    )
    print('Instance created and marked as complete')
"

# Clear cache to ensure changes are visible
echo "Clearing cache..."
python manage.py clear_cache

echo ""
echo "=== Setup Complete ==="
echo "Admin Email: $ADMIN_EMAIL"
echo "Admin Password: $ADMIN_PASSWORD"
echo "Access Plane at: http://localhost/"
echo ""
