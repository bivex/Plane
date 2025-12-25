# Plane Solo-Developer Setup

Complete automated setup for using Plane as a solo desktop application developer.

## 🚀 Quick Start

```bash
# Make sure Docker is running
# Then run the setup script
./setup-solo-dev.sh
```

That's it! The script will:
- ✅ Start all Plane containers
- ✅ Configure admin user
- ✅ Create solo-dev workspace
- ✅ Set up desktop-app project
- ✅ Configure all states, labels, modules, views
- ✅ Create sample issue
- ✅ Set up weekly development cycle

## 📋 What Gets Configured

### **Workspace**
- **Name:** `solo-dev`
- **URL:** `http://localhost:33333/solo-dev`

### **Project**
- **Name:** `desktop-app`
- **Identifier:** `DESKTOP`
- **URL:** `http://localhost:33333/solo-dev/projects/desktop-app`

### **States** (Kanban Workflow)
1. **Backlog** (Gray) - Items to work on
2. **Ready** (Blue) - Ready to start
3. **In Progress** (Orange) - Currently working
4. **Testing** (Red-Orange) - Ready for testing
5. **Released** (Green) - Successfully released
6. **Blocked** (Red) - Blocked by dependencies

### **Labels**
- `windows` - Windows platform specific
- `macos` - macOS platform specific
- `cross-platform` - Works on both platforms
- `feature` - New features
- `bug` - Bug fixes
- `tech-debt` - Technical debt
- `refactor` - Code refactoring
- `release` - Release-related work

### **Modules** (Product Areas)
- **Core** - Main application logic
- **UI** - User interface
- **Updater** - Update system
- **Licensing** - License management
- **Installer** - Installation packages
- **Infrastructure** - CI/CD and tooling

### **Views** (Quick Filters)
- **Today** - Recently updated issues
- **In Progress** - Active work
- **Bugs** - All bug reports
- **Release checklist** - Items ready for release

### **Sample Issue**
"Add auto-update support (Windows + macOS)" with `cross-platform` and `feature` labels.

### **Weekly Cycle**
Automatic weekly development cycle for focus and planning.

## 🔐 Access Information

- **URL:** `http://localhost:33333`
- **Email:** `admin@plane.local`
- **Password:** `admin123`

## 📝 Solo-Dev Workflow

1. **Planning:** Use modules to organize features
2. **Development:** Move issues through states
3. **Tracking:** Use views for quick access
4. **Releases:** Use labels and release checklist view

## 🛠️ Manual Customization

If you need to modify the setup:

```bash
# Edit the script
nano setup-solo-dev.sh

# Change these variables at the top:
WORKSPACE_SLUG="your-workspace"
WORKSPACE_NAME="Your Workspace"
PROJECT_NAME="your-project"
PROJECT_IDENTIFIER="YOURPROJ"
```

## 🔄 Reset Everything

To start fresh:

```bash
# Stop containers
docker-compose down -v

# Run setup again
./setup-solo-dev.sh
```

## 📚 Definition of Done

Before marking issues as "Released":
- ✅ Builds on Windows
- ✅ Builds on macOS
- ✅ Manual smoke test passed
- ✅ Version bumped
- ✅ Changelog updated

---

**Perfect for solo desktop app development with Windows + macOS support!** 🎯
