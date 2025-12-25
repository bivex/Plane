#!/bin/sh
set -e

echo "Preparing Plane web application..."

# Copy static files to standalone directory if not already present
if [ ! -d "/app/web/.next/standalone/web/.next/static" ]; then
    echo "Copying static files..."
    cp -r /app/web/.next/static /app/web/.next/standalone/web/.next/static
fi

# Copy public directory to standalone directory if not already present
if [ ! -d "/app/web/.next/standalone/web/public" ]; then
    echo "Copying public files..."
    cp -r /app/web/public /app/web/.next/standalone/web/public
fi

echo "Starting Next.js server..."
cd /app/web/.next/standalone/web
exec node server.js
