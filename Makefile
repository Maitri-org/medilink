# Medilink - Production-Ready Makefile for Dockerized Django Project
# =======================================================================
# This Makefile manages the complete lifecycle of the Medilink Django application
# running in Docker containers with PostgreSQL, Redis, PostgREST, and other services.

.PHONY: help up down build logs logs-all status migrate migrations superuser shell collectstatic \
        lock sync add db-shell format lint test clean restart exec bash redis-cli \
        db-backup db-restore db-reset pgadmin-logs redis-logs mailpit-logs api-logs \
        ps top prune restart-service stop-service start-service health-check \
        django-check django-urls django-showmigrations coverage install-dev remove

# Color codes for beautiful output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
RESET := \033[0m
BOLD := \033[1m

# Container and service names
DJANGO_CONTAINER := medilink
DB_CONTAINER := medilink-db
REDIS_CONTAINER := medilink-redis
PGADMIN_CONTAINER := medilink-pgadmin
MAILPIT_CONTAINER := medilink-mailpit
API_CONTAINER := medilink-api_fast
REDIS_INSIGHT_CONTAINER := medilink-redis-insight
COMPOSE := docker-compose

# Database configuration (can be overridden)
DB_USER ?= postgres
DB_NAME ?= medilink

# Default target - shows help
help: ## Display this help message with all available commands
	@echo "$(BOLD)$(CYAN)╔═══════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(BOLD)$(CYAN)║          MEDILINK - Docker Django Makefile Commands          ║$(RESET)"
	@echo "$(BOLD)$(CYAN)╚═══════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(BOLD)$(GREEN)SECTION 1: Docker Lifecycle$(RESET)"
	@echo "  $(CYAN)make up$(RESET)                      - Start all containers in detached mode"
	@echo "  $(CYAN)make down$(RESET)                    - Stop and remove containers and networks"
	@echo "  $(CYAN)make build$(RESET)                   - Force rebuild images and start containers"
	@echo "  $(CYAN)make restart$(RESET)                 - Restart all containers"
	@echo "  $(CYAN)make restart-service svc=<n>$(RESET) - Restart specific service"
	@echo "  $(CYAN)make stop-service svc=<n>$(RESET)    - Stop specific service"
	@echo "  $(CYAN)make start-service svc=<n>$(RESET)   - Start specific service"
	@echo "  $(CYAN)make logs$(RESET)                    - Follow logs of the Django container"
	@echo "  $(CYAN)make logs-all$(RESET)                - Follow logs of all containers"
	@echo "  $(CYAN)make status$(RESET)                  - Show status of running containers"
	@echo "  $(CYAN)make ps$(RESET)                      - List all containers with detailed info"
	@echo "  $(CYAN)make top$(RESET)                     - Display running processes in containers"
	@echo "  $(CYAN)make health-check$(RESET)            - Check health status of all services"
	@echo "  $(CYAN)make prune$(RESET)                   - Remove unused Docker resources"
	@echo ""
	@echo "$(BOLD)$(GREEN)SECTION 2: Django Management$(RESET)"
	@echo "  $(CYAN)make migrate$(RESET)                 - Run database migrations"
	@echo "  $(CYAN)make migrations$(RESET)              - Create new migrations"
	@echo "  $(CYAN)make superuser$(RESET)               - Create Django superuser (interactive)"
	@echo "  $(CYAN)make shell$(RESET)                   - Open Django shell (shell_plus if available)"
	@echo "  $(CYAN)make bash$(RESET)                    - Open bash shell in Django container"
	@echo "  $(CYAN)make collectstatic$(RESET)           - Collect static files"
	@echo "  $(CYAN)make django-check$(RESET)            - Run Django system checks"
	@echo "  $(CYAN)make django-urls$(RESET)             - Show all registered URLs"
	@echo "  $(CYAN)make django-showmigrations$(RESET)   - Show migration status"
	@echo "  $(CYAN)make exec cmd='<command>'$(RESET)    - Execute custom command in Django container"
	@echo ""
	@echo "$(BOLD)$(GREEN)SECTION 3: Dependency Management$(RESET)"
	@echo "  $(CYAN)make lock$(RESET)                    - Generate/update uv.lock file"
	@echo "  $(CYAN)make sync$(RESET)                    - Install dependencies from lockfile"
	@echo "  $(CYAN)make install-dev$(RESET)             - Install development dependencies"
	@echo "  $(CYAN)make add pkg=<name>$(RESET)          - Add a new package (e.g., make add pkg=requests)"
	@echo "  $(CYAN)make remove pkg=<name>$(RESET)       - Remove a package"
	@echo ""
	@echo "$(BOLD)$(GREEN)SECTION 4: Database & Quality$(RESET)"
	@echo "  $(CYAN)make db-shell$(RESET)                - Open PostgreSQL shell (psql)"
	@echo "  $(CYAN)make db-backup$(RESET)               - Backup database to file"
	@echo "  $(CYAN)make db-restore file=<path>$(RESET)  - Restore database from backup"
	@echo "  $(CYAN)make db-reset$(RESET)                - Reset database (WARNING: destructive)"
	@echo "  $(CYAN)make format$(RESET)                  - Format code with ruff"
	@echo "  $(CYAN)make lint$(RESET)                    - Lint code with ruff"
	@echo "  $(CYAN)make test$(RESET)                    - Run Django tests"
	@echo "  $(CYAN)make coverage$(RESET)                - Run tests with coverage report"
	@echo ""
	@echo "$(BOLD)$(GREEN)SECTION 5: Service-Specific Commands$(RESET)"
	@echo "  $(CYAN)make redis-cli$(RESET)               - Open Redis CLI"
	@echo "  $(CYAN)make redis-logs$(RESET)              - Follow Redis logs"
	@echo "  $(CYAN)make pgadmin-logs$(RESET)            - Follow pgAdmin logs"
	@echo "  $(CYAN)make mailpit-logs$(RESET)            - Follow Mailpit logs"
	@echo "  $(CYAN)make api-logs$(RESET)                - Follow PostgREST API logs"
	@echo ""
	@echo "$(BOLD)$(GREEN)SECTION 6: Utilities$(RESET)"
	@echo "  $(CYAN)make clean$(RESET)                   - Remove cache files and artifacts"
	@echo "  $(CYAN)make help$(RESET)                    - Display this help message"
	@echo ""
	@echo "$(BOLD)$(YELLOW)Example Workflows:$(RESET)"
	@echo "  $(GREEN)Initial Setup:$(RESET)       make build && make migrate && make superuser"
	@echo "  $(GREEN)Daily Dev:$(RESET)           make up && make logs"
	@echo "  $(GREEN)Add Package:$(RESET)         make add pkg=celery && make build"
	@echo "  $(GREEN)Run Command:$(RESET)         make exec cmd='python manage.py check'"
	@echo "  $(GREEN)Service Control:$(RESET)     make restart-service svc=redis"
	@echo "  $(GREEN)Database Backup:$(RESET)     make db-backup"
	@echo ""

# =============================================================================
# SECTION 1: Docker Lifecycle
# =============================================================================

up: ## Start all containers in detached mode
	@echo "$(BOLD)$(GREEN)🚀 Starting Medilink containers...$(RESET)"
	@$(COMPOSE) up -d
	@echo "$(GREEN)✓ All containers started successfully$(RESET)"

down: ## Stop and remove containers and networks
	@echo "$(BOLD)$(YELLOW)🛑 Stopping Medilink containers...$(RESET)"
	@$(COMPOSE) down
	@echo "$(YELLOW)✓ All containers stopped and removed$(RESET)"

build: ## Force rebuild images and start containers
	@echo "$(BOLD)$(GREEN)🔨 Building Medilink images...$(RESET)"
	@$(COMPOSE) up --build -d
	@echo "$(GREEN)✓ Build complete and containers started$(RESET)"

restart: ## Restart all containers
	@echo "$(BOLD)$(YELLOW)🔄 Restarting Medilink containers...$(RESET)"
	@$(COMPOSE) restart
	@echo "$(YELLOW)✓ All containers restarted$(RESET)"

logs: ## Follow logs of the Django container
	@echo "$(BOLD)$(CYAN)📋 Following logs for $(DJANGO_CONTAINER)...$(RESET)"
	@docker logs -f $(DJANGO_CONTAINER)

status: ## Show status of running containers
	@echo "$(BOLD)$(CYAN)📊 Container Status:$(RESET)"
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

ps: ## List all containers with detailed info
	@echo "$(BOLD)$(CYAN)📋 Detailed Container List:$(RESET)"
	@$(COMPOSE) ps -a

top: ## Display running processes in containers
	@echo "$(BOLD)$(CYAN)⚡ Running Processes:$(RESET)"
	@$(COMPOSE) top

logs-all: ## Follow logs of all containers
	@echo "$(BOLD)$(CYAN)📋 Following all container logs...$(RESET)"
	@$(COMPOSE) logs -f

health-check: ## Check health status of all services
	@echo "$(BOLD)$(CYAN)🏥 Health Check Status:$(RESET)"
	@echo ""
	@echo "$(BOLD)Django Service:$(RESET)"
	@docker inspect --format='{{.State.Health.Status}}' $(DJANGO_CONTAINER) 2>/dev/null || echo "No health check configured"
	@echo ""
	@echo "$(BOLD)Database Service:$(RESET)"
	@docker exec $(DB_CONTAINER) pg_isready -U $(DB_USER) 2>/dev/null && echo "$(GREEN)✓ Healthy$(RESET)" || echo "$(RED)✗ Unhealthy$(RESET)"
	@echo ""
	@echo "$(BOLD)Redis Service:$(RESET)"
	@docker exec $(REDIS_CONTAINER) redis-cli ping 2>/dev/null && echo "$(GREEN)✓ Healthy$(RESET)" || echo "$(RED)✗ Unhealthy$(RESET)"

restart-service: ## Restart specific service (usage: make restart-service svc=db)
ifndef svc
	@echo "$(BOLD)$(RED)❌ Error: Service name required$(RESET)"
	@echo "$(YELLOW)Usage: make restart-service svc=<service-name>$(RESET)"
	@echo "$(YELLOW)Available services: medilink, db, redis, api_fast, pgadmin, mailpit, redis-insight$(RESET)"
	@echo "$(YELLOW)Example: make restart-service svc=db$(RESET)"
	@exit 1
endif
	@echo "$(BOLD)$(YELLOW)🔄 Restarting service: $(svc)...$(RESET)"
	@$(COMPOSE) restart $(svc)
	@echo "$(YELLOW)✓ Service '$(svc)' restarted$(RESET)"

stop-service: ## Stop specific service (usage: make stop-service svc=redis)
ifndef svc
	@echo "$(BOLD)$(RED)❌ Error: Service name required$(RESET)"
	@echo "$(YELLOW)Usage: make stop-service svc=<service-name>$(RESET)"
	@echo "$(YELLOW)Example: make stop-service svc=redis$(RESET)"
	@exit 1
endif
	@echo "$(BOLD)$(YELLOW)⏸️  Stopping service: $(svc)...$(RESET)"
	@$(COMPOSE) stop $(svc)
	@echo "$(YELLOW)✓ Service '$(svc)' stopped$(RESET)"

start-service: ## Start specific service (usage: make start-service svc=mailpit)
ifndef svc
	@echo "$(BOLD)$(RED)❌ Error: Service name required$(RESET)"
	@echo "$(YELLOW)Usage: make start-service svc=<service-name>$(RESET)"
	@echo "$(YELLOW)Example: make start-service svc=mailpit$(RESET)"
	@exit 1
endif
	@echo "$(BOLD)$(GREEN)▶️  Starting service: $(svc)...$(RESET)"
	@$(COMPOSE) start $(svc)
	@echo "$(GREEN)✓ Service '$(svc)' started$(RESET)"

prune: ## Remove unused Docker resources
	@echo "$(BOLD)$(YELLOW)🗑️  Pruning unused Docker resources...$(RESET)"
	@docker system prune -f
	@echo "$(YELLOW)✓ Prune complete$(RESET)"

# =============================================================================
# SECTION 2: Django Management (executed inside container)
# =============================================================================

migrate: ## Run database migrations
	@echo "$(BOLD)$(GREEN)🗄️  Running migrations...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) python manage.py migrate
	@echo "$(GREEN)✓ Migrations applied successfully$(RESET)"

migrations: ## Create new migrations
	@echo "$(BOLD)$(GREEN)📝 Creating migrations...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) python manage.py makemigrations
	@echo "$(GREEN)✓ Migrations created$(RESET)"

superuser: ## Create Django superuser (interactive)
	@echo "$(BOLD)$(GREEN)👤 Creating superuser...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) python manage.py createsuperuser

shell: ## Open Django shell (shell_plus if available)
	@echo "$(BOLD)$(CYAN)🐚 Opening Django shell...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) sh -c \
		"python manage.py shell_plus 2>/dev/null || python manage.py shell"

collectstatic: ## Collect static files
	@echo "$(BOLD)$(GREEN)📦 Collecting static files...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) python manage.py collectstatic --noinput
	@echo "$(GREEN)✓ Static files collected$(RESET)"

bash: ## Open bash shell in Django container
	@echo "$(BOLD)$(CYAN)🐚 Opening bash shell in $(DJANGO_CONTAINER)...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) /bin/bash

exec: ## Execute custom command in Django container (usage: make exec cmd='python manage.py --help')
ifndef cmd
	@echo "$(BOLD)$(RED)❌ Error: Command required$(RESET)"
	@echo "$(YELLOW)Usage: make exec cmd='<your-command>'$(RESET)"
	@echo "$(YELLOW)Examples:$(RESET)"
	@echo "  make exec cmd='python manage.py check'"
	@echo "  make exec cmd='ls -la /app'"
	@echo "  make exec cmd='pip list'"
	@exit 1
endif
	@echo "$(BOLD)$(CYAN)⚡ Executing: $(cmd)$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) sh -c "$(cmd)"

django-check: ## Run Django system checks
	@echo "$(BOLD)$(GREEN)🔍 Running Django system checks...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) python manage.py check
	@echo "$(GREEN)✓ System checks passed$(RESET)"

django-urls: ## Show all registered URLs
	@echo "$(BOLD)$(CYAN)🌐 Registered URLs:$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) python manage.py show_urls 2>/dev/null || \
		docker exec -it $(DJANGO_CONTAINER) python manage.py shell -c "from django.urls import get_resolver; print('\n'.join([str(p.pattern) for p in get_resolver().url_patterns]))"

django-showmigrations: ## Show migration status
	@echo "$(BOLD)$(CYAN)📋 Migration Status:$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) python manage.py showmigrations

# =============================================================================
# SECTION 3: Dependency Management (using uv)
# =============================================================================

lock: ## Generate/update uv.lock file
	@echo "$(BOLD)$(GREEN)🔒 Locking dependencies with uv...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) uv lock
	@echo "$(GREEN)✓ Dependencies locked$(RESET)"

sync: ## Install dependencies from lockfile
	@echo "$(BOLD)$(GREEN)📥 Syncing dependencies with uv...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) uv sync
	@echo "$(GREEN)✓ Dependencies synced$(RESET)"

install-dev: ## Install development dependencies
	@echo "$(BOLD)$(GREEN)🔧 Installing development dependencies...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) uv sync --dev
	@echo "$(GREEN)✓ Development dependencies installed$(RESET)"

add: ## Add a new package (usage: make add pkg=requests)
ifndef pkg
	@echo "$(BOLD)$(RED)❌ Error: Package name required$(RESET)"
	@echo "$(YELLOW)Usage: make add pkg=<package-name>$(RESET)"
	@echo "$(YELLOW)Examples:$(RESET)"
	@echo "  make add pkg=requests"
	@echo "  make add pkg=celery"
	@echo "  make add pkg='django-cors-headers>=4.0'"
	@exit 1
endif
	@echo "$(BOLD)$(GREEN)➕ Adding package: $(pkg)...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) uv add $(pkg)
	@echo "$(GREEN)✓ Package '$(pkg)' added successfully$(RESET)"

remove: ## Remove a package (usage: make remove pkg=requests)
ifndef pkg
	@echo "$(BOLD)$(RED)❌ Error: Package name required$(RESET)"
	@echo "$(YELLOW)Usage: make remove pkg=<package-name>$(RESET)"
	@echo "$(YELLOW)Example: make remove pkg=requests$(RESET)"
	@exit 1
endif
	@echo "$(BOLD)$(YELLOW)➖ Removing package: $(pkg)...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) uv remove $(pkg)
	@echo "$(YELLOW)✓ Package '$(pkg)' removed successfully$(RESET)"

# =============================================================================
# SECTION 4: Database & Quality
# =============================================================================

db-shell: ## Open PostgreSQL shell (psql)
	@echo "$(BOLD)$(CYAN)🗄️  Opening PostgreSQL shell...$(RESET)"
	@docker exec -it $(DB_CONTAINER) psql -U $(DB_USER) -d $(DB_NAME)

db-backup: ## Backup database to file
	@echo "$(BOLD)$(GREEN)💾 Creating database backup...$(RESET)"
	@mkdir -p backups
	@docker exec -t $(DB_CONTAINER) pg_dump -U $(DB_USER) $(DB_NAME) > backups/backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)✓ Backup created in backups/ directory$(RESET)"
	@ls -lh backups/ | tail -1

db-restore: ## Restore database from backup (usage: make db-restore file=backups/backup.sql)
ifndef file
	@echo "$(BOLD)$(RED)❌ Error: Backup file required$(RESET)"
	@echo "$(YELLOW)Usage: make db-restore file=<path-to-backup>$(RESET)"
	@echo "$(YELLOW)Example: make db-restore file=backups/backup_20231215_120000.sql$(RESET)"
	@echo ""
	@echo "$(CYAN)Available backups:$(RESET)"
	@ls -lh backups/ 2>/dev/null || echo "No backups found"
	@exit 1
endif
	@echo "$(BOLD)$(YELLOW)📥 Restoring database from $(file)...$(RESET)"
	@docker exec -i $(DB_CONTAINER) psql -U $(DB_USER) $(DB_NAME) < $(file)
	@echo "$(YELLOW)✓ Database restored$(RESET)"

db-reset: ## Reset database (WARNING: destructive)
	@echo "$(BOLD)$(RED)⚠️  WARNING: This will destroy all data in the database!$(RESET)"
	@echo "$(YELLOW)Database: $(DB_NAME)$(RESET)"
	@read -p "Are you absolutely sure? Type 'YES' to continue: " confirm; \
	if [ "$$confirm" = "YES" ]; then \
		echo "$(BOLD)$(RED)🗑️  Resetting database...$(RESET)"; \
		docker exec -it $(DB_CONTAINER) psql -U $(DB_USER) -c "DROP DATABASE IF EXISTS $(DB_NAME);"; \
		docker exec -it $(DB_CONTAINER) psql -U $(DB_USER) -c "CREATE DATABASE $(DB_NAME);"; \
		echo "$(YELLOW)✓ Database reset complete$(RESET)"; \
		echo "$(CYAN)Run 'make migrate' to apply migrations$(RESET)"; \
	else \
		echo "$(GREEN)Cancelled. Database was not modified.$(RESET)"; \
	fi

format: ## Format code with ruff
	@echo "$(BOLD)$(GREEN)✨ Formatting code with ruff...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) ruff format .
	@echo "$(GREEN)✓ Code formatted$(RESET)"

lint: ## Lint code with ruff
	@echo "$(BOLD)$(CYAN)🔍 Linting code with ruff...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) ruff check .
	@echo "$(CYAN)✓ Linting complete$(RESET)"

test: ## Run Django tests
	@echo "$(BOLD)$(GREEN)🧪 Running Django tests...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) python manage.py test
	@echo "$(GREEN)✓ Tests complete$(RESET)"

coverage: ## Run tests with coverage report
	@echo "$(BOLD)$(GREEN)📊 Running tests with coverage...$(RESET)"
	@docker exec -it $(DJANGO_CONTAINER) sh -c "coverage run --source='.' manage.py test && coverage report && coverage html"
	@echo "$(GREEN)✓ Coverage report generated in htmlcov/$(RESET)"
	@echo "$(CYAN)Open htmlcov/index.html in your browser to view the report$(RESET)"

# =============================================================================
# SECTION 5: Service-Specific Commands
# =============================================================================

redis-cli: ## Open Redis CLI
	@echo "$(BOLD)$(CYAN)🔴 Opening Redis CLI...$(RESET)"
	@docker exec -it $(REDIS_CONTAINER) redis-cli

redis-logs: ## Follow Redis logs
	@echo "$(BOLD)$(CYAN)📋 Following Redis logs...$(RESET)"
	@docker logs -f $(REDIS_CONTAINER)

pgadmin-logs: ## Follow pgAdmin logs
	@echo "$(BOLD)$(CYAN)📋 Following pgAdmin logs...$(RESET)"
	@docker logs -f $(PGADMIN_CONTAINER)

mailpit-logs: ## Follow Mailpit logs
	@echo "$(BOLD)$(CYAN)📋 Following Mailpit logs...$(RESET)"
	@docker logs -f $(MAILPIT_CONTAINER)

api-logs: ## Follow PostgREST API logs
	@echo "$(BOLD)$(CYAN)📋 Following PostgREST API logs...$(RESET)"
	@docker logs -f $(API_CONTAINER)

# =============================================================================
# SECTION 6: Utilities
# =============================================================================

clean: ## Remove cache files and artifacts
	@echo "$(BOLD)$(YELLOW)🧹 Cleaning Python cache files and artifacts...$(RESET)"
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type f -name "*.pyo" -delete 2>/dev/null || true
	@find . -type f -name "*.pyd" -delete 2>/dev/null || true
	@find . -type f -name ".coverage" -delete 2>/dev/null || true
	@find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name "htmlcov" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(YELLOW)✓ Cleanup complete$(RESET)"