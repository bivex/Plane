#!/bin/bash

# Plane Solo-Dev Setup Script
# Sets up Plane with complete solo developer configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADMIN_EMAIL="admin@plane.local"
ADMIN_PASSWORD="admin123"
WORKSPACE_SLUG="solo-dev"
WORKSPACE_NAME="solo-dev"
PROJECT_NAME="desktop-app"
PROJECT_IDENTIFIER="DESKTOP"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_docker() {
    log_info "Checking Docker..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker first."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker."
        exit 1
    fi

    log_success "Docker is running"
}

wait_for_db() {
    log_info "Waiting for database to be ready..."
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if docker-compose exec -T plane-db pg_isready -U plane -d plane &>/dev/null; then
            log_success "Database is ready"
            return 0
        fi

        log_info "Attempt $attempt/$max_attempts - waiting for database..."
        sleep 5
        ((attempt++))
    done

    log_error "Database failed to start"
    exit 1
}

setup_plane() {
    log_info "Starting Plane containers..."
    cd "$SCRIPT_DIR"
    docker-compose up -d

    wait_for_db

    log_info "Waiting for Plane initialization to complete..."
    # The plane-init service runs automatically and sets up the admin user
    # Wait for it to complete
    local init_timeout=60
    local init_elapsed=0

    while [ $init_elapsed -lt $init_timeout ]; do
        if docker-compose ps plane-init | grep -q "Exit"; then
            log_success "Plane initialization complete"
            break
        fi
        sleep 2
        init_elapsed=$((init_elapsed + 2))
    done

    if [ $init_elapsed -ge $init_timeout ]; then
        log_warning "Plane initialization may still be running in background"
    fi

    log_success "Plane basic setup complete"
}

create_workspace() {
    log_info "Creating workspace '$WORKSPACE_NAME'..."

    docker-compose exec -T plane-db psql -U plane -d plane -c "
    -- Delete existing workspace if it exists
    DELETE FROM workspaces WHERE slug = '$WORKSPACE_SLUG';

    -- Create new workspace
    INSERT INTO workspaces (id, name, slug, owner_id, created_at, updated_at)
    VALUES (gen_random_uuid(), '$WORKSPACE_NAME', '$WORKSPACE_SLUG',
            (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'),
            NOW(), NOW());
    " > /dev/null

    log_success "Workspace '$WORKSPACE_NAME' created"
}

setup_workspace_membership() {
    log_info "Setting up workspace membership..."

    docker-compose exec -T plane-db psql -U plane -d plane -c "
    -- Delete existing membership if any
    DELETE FROM workspace_members
    WHERE workspace_id = (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG')
      AND member_id = (SELECT id FROM users WHERE email = '$ADMIN_EMAIL');

    -- Add admin user to workspace
    INSERT INTO workspace_members (id, member_id, workspace_id, role, created_by_id, updated_by_id, created_at, updated_at, view_props, default_props, issue_props, is_active)
    SELECT
        gen_random_uuid(),
        u.id,
        w.id,
        20, -- Admin role
        u.id,
        u.id,
        NOW(),
        NOW(),
        '{}', -- view_props (required JSONB)
        '{}', -- default_props (required JSONB)
        '{}', -- issue_props (required JSONB)
        true  -- is_active (active member)
    FROM workspaces w
    CROSS JOIN users u
    WHERE w.slug = '$WORKSPACE_SLUG'
      AND u.email = '$ADMIN_EMAIL';
    " > /dev/null

    log_success "Workspace membership configured"
}

create_project() {
    log_info "Creating project '$PROJECT_NAME'..."

    docker-compose exec -T plane-db psql -U plane -d plane -c "
    -- Delete existing project if it exists
    DELETE FROM projects WHERE identifier = '$PROJECT_IDENTIFIER';

    -- Create new project
    INSERT INTO projects (id, name, identifier, description, workspace_id, created_at, updated_at, created_by_id)
    VALUES (gen_random_uuid(), '$PROJECT_NAME', '$PROJECT_IDENTIFIER', 'Cross-platform desktop application',
            (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
            NOW(), NOW(),
            (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'));
    " > /dev/null

    log_success "Project '$PROJECT_NAME' created"
}

setup_states() {
    log_info "Setting up project states..."

    docker-compose exec -T plane-db psql -U plane -d plane -c "
    -- Delete existing states for this project
    DELETE FROM states WHERE project_id = (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER');

    -- Create solo-dev states
    INSERT INTO states (id, name, description, color, slug, project_id, workspace_id, sequence, \"group\", \"default\", is_triage, created_at, updated_at, created_by_id) VALUES
    (gen_random_uuid(), 'Backlog', 'Items to be worked on', '#A3A3A3', 'backlog',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     15000, 'backlog', false, false, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Ready', 'Ready to be worked on', '#3B82F6', 'ready',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     25000, 'backlog', false, false, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'In Progress', 'Currently being worked on', '#F59E0B', 'in-progress',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     35000, 'backlog', false, false, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Testing', 'Ready for testing', '#EA580C', 'testing',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     45000, 'backlog', false, false, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Released', 'Successfully released', '#16A34A', 'released',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     55000, 'backlog', false, false, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Blocked', 'Blocked by dependencies', '#DC2626', 'blocked',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     65000, 'backlog', false, false, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'));
    " > /dev/null

    log_success "States configured"
}

setup_labels() {
    log_info "Setting up project labels..."

    docker-compose exec -T plane-db psql -U plane -d plane -c "
    -- Delete existing labels for this project
    DELETE FROM labels WHERE project_id = (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER');

    -- Create solo-dev labels
    INSERT INTO labels (id, name, description, project_id, workspace_id, color, sort_order, created_at, updated_at, created_by_id) VALUES
    (gen_random_uuid(), 'windows', 'Windows platform specific',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '#2563EB', 1000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'macos', 'macOS platform specific',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '#6B7280', 2000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'cross-platform', 'Works on both Windows and macOS',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '#7C3AED', 3000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'feature', 'New feature or enhancement',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '#10B981', 4000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'bug', 'Bug fix or issue resolution',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '#DC2626', 5000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'tech-debt', 'Technical debt or refactoring needed',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '#F59E0B', 6000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'refactor', 'Code refactoring or cleanup',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '#EAB308', 7000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'release', 'Release-related work',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '#166534', 8000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'));
    " > /dev/null

    log_success "Labels configured"
}

setup_modules() {
    log_info "Setting up project modules..."

    docker-compose exec -T plane-db psql -U plane -d plane -c "
    -- Delete existing modules for this project
    DELETE FROM modules WHERE project_id = (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER');

    -- Create solo-dev modules
    INSERT INTO modules (id, name, description, status, project_id, workspace_id, view_props, logo_props, sort_order, created_at, updated_at, created_by_id) VALUES
    (gen_random_uuid(), 'Core', 'Основная логика приложения', 'planned',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 1000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'UI', 'Пользовательский интерфейс', 'planned',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 2000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Updater', 'Система обновлений', 'planned',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 3000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Licensing', 'Лицензирование', 'planned',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 4000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Installer', 'Установщики', 'planned',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 5000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Infrastructure', 'Инфраструктура и CI/CD', 'planned',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 6000, NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'));
    " > /dev/null

    log_success "Modules configured"
}

setup_views() {
    log_info "Setting up project views..."

    docker-compose exec -T plane-db psql -U plane -d plane -c "
    -- Delete existing views for this project
    DELETE FROM issue_views WHERE project_id = (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER');

    -- Create solo-dev views
    INSERT INTO issue_views (id, name, description, query, access, filters, project_id, workspace_id, display_filters, display_properties, sort_order, logo_props, is_locked, owned_by_id, created_at, updated_at, created_by_id) VALUES
    (gen_random_uuid(), 'Today', 'Issues updated today', '{}', 0, '{\"updated_at\": [{\"operator\": \"is\", \"value\": \"today\"}]}',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 1000, '{}', false,
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'),
     NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'In Progress', 'Currently active work', '{}', 0, '{\"state\": [{\"operator\": \"is\", \"value\": \"In Progress\"}]}',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 2000, '{}', false,
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'),
     NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Bugs', 'Bug reports and fixes', '{}', 0, '{\"labels\": [{\"operator\": \"is\", \"value\": \"bug\"}]}',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 3000, '{}', false,
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'),
     NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL')),

    (gen_random_uuid(), 'Release checklist', 'Items ready for release', '{}', 0, '{\"state\": [{\"operator\": \"is\", \"value\": [\"Testing\", \"Released\"]}]}',
     (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
     (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
     '{}', '{}', 4000, '{}', false,
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'),
     NOW(), NOW(),
     (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'));
    " > /dev/null

    log_success "Views configured"
}

create_sample_issue() {
    log_info "Creating sample issue..."

    docker-compose exec -T plane-db psql -U plane -d plane -c "
    -- Delete existing sample issue
    DELETE FROM issues WHERE name LIKE 'Add auto-update support%';

    -- Create sample issue
    INSERT INTO issues (id, name, description, priority, sequence_id, project_id, state_id, workspace_id, description_html, sort_order, is_draft, created_at, updated_at, created_by_id)
    VALUES (gen_random_uuid(), 'Add auto-update support (Windows + macOS)',
            '{\"type\": \"doc\", \"content\": [{\"type\": \"paragraph\", \"content\": [{\"type\": \"text\", \"text\": \"Implement automatic updates for both platforms\"}]}]}',
            'medium', 1,
            (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
            (SELECT id FROM states WHERE name = 'Backlog' AND project_id = (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER')),
            (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
            '<p>Implement automatic updates for both platforms</p>',
            1000, false, NOW(), NOW(),
            (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'));

    -- Add labels to sample issue
    INSERT INTO issue_labels (id, issue_id, label_id, project_id, workspace_id, created_by_id, created_at, updated_at)
    SELECT
        gen_random_uuid(),
        i.id,
        l.id,
        i.project_id,
        i.workspace_id,
        i.created_by_id,
        NOW(),
        NOW()
    FROM issues i
    CROSS JOIN labels l
    WHERE i.name LIKE 'Add auto-update support%'
      AND l.name IN ('cross-platform', 'feature')
      AND l.project_id = i.project_id;
    " > /dev/null

    log_success "Sample issue created"
}

create_cycle() {
    log_info "Creating weekly development cycle..."

    docker-compose exec -T plane-db psql -U plane -d plane -c "
    -- Delete existing cycles for this project
    DELETE FROM cycles WHERE project_id = (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER');

    -- Create weekly cycle
    INSERT INTO cycles (id, name, description, start_date, end_date, owned_by_id, project_id, workspace_id, view_props, sort_order, progress_snapshot, logo_props, created_at, updated_at, created_by_id)
    VALUES (gen_random_uuid(), 'Week ' || EXTRACT(WEEK FROM CURRENT_DATE), 'Weekly development cycle',
            CURRENT_DATE, CURRENT_DATE + INTERVAL '6 days',
            (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'),
            (SELECT id FROM projects WHERE identifier = '$PROJECT_IDENTIFIER'),
            (SELECT id FROM workspaces WHERE slug = '$WORKSPACE_SLUG'),
            '{}', 1000, '{}', '{}', NOW(), NOW(),
            (SELECT id FROM users WHERE email = '$ADMIN_EMAIL'));
    " > /dev/null

    log_success "Weekly cycle created"
}

restart_services() {
    log_info "Restarting Plane services to apply changes..."
    cd "$SCRIPT_DIR"
    docker-compose restart plane-api plane-web > /dev/null 2>&1
    sleep 5
    log_success "Services restarted"
}

show_completion() {
    echo
    log_success "🎉 Solo-dev Plane setup complete!"
    echo
    echo -e "${BLUE}Access your Plane instance:${NC}"
    echo "  URL: http://localhost:33333"
    echo "  Email: $ADMIN_EMAIL"
    echo "  Password: $ADMIN_PASSWORD"
    echo
    echo -e "${BLUE}Your workspace:${NC}"
    echo "  Name: $WORKSPACE_NAME"
    echo "  URL: http://localhost:33333/$WORKSPACE_SLUG"
    echo
    echo -e "${BLUE}Project:${NC}"
    echo "  Name: $PROJECT_NAME"
    echo "  URL: http://localhost:33333/$WORKSPACE_SLUG/projects/$PROJECT_IDENTIFIER"
    echo
    echo -e "${YELLOW}Configured:${NC}"
    echo "  ✅ 6 Project States (Backlog → Released + Blocked)"
    echo "  ✅ 8 Labels (windows, macos, cross-platform, feature, bug, tech-debt, refactor, release)"
    echo "  ✅ 6 Modules (Core, UI, Updater, Licensing, Installer, Infrastructure)"
    echo "  ✅ 4 Views (Today, In Progress, Bugs, Release checklist)"
    echo "  ✅ Sample Issue with labels"
    echo "  ✅ Weekly Development Cycle"
    echo
    log_success "Ready for solo desktop development! 🚀"
}

# Main execution
main() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Plane Solo-Dev Setup Script   ${NC}"
    echo -e "${BLUE}================================${NC}"
    echo

    check_docker
    setup_plane
    create_workspace
    setup_workspace_membership
    create_project
    setup_states
    setup_labels
    setup_modules
    setup_views
    create_sample_issue
    create_cycle
    restart_services
    show_completion
}

# Run main function
main "$@"
