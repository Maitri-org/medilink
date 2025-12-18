# syntax=docker/dockerfile:1

#==========================================================================================
# Dockerfile for building a Docker image for Medilink application
# Author: Vedant Manoj Kulkarni
# Email: vedantkulkarni.20.000@gmail.com
# Date: 14th disember 2025
# Version: 1.0
# Description: This Dockerfile uses a multi-stage build process to create a lightweight
#              Docker image for the Medilink application. The first stage builds the
#              application using a specialized base image with UV package manager, while
#              the second stage creates a minimal runtime environment.
#==========================================================================================


# ==============================================================================
# Stage 1: The Builder (Dependencies Only)
# ==============================================================================
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /Medilink

# 1. Install Dependencies
# We ONLY copy lock files here. This ensures the cache is only invalidated
# if dependencies change, not when you change application code.
COPY pyproject.toml uv.lock ./

# --frozen: strict version matching from uv.lock
# --no-install-project: installs libraries only, keeping the image light
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project

# ==============================================================================
# Stage 2: The Runner (Production)
# ==============================================================================
FROM python:3.12-slim-bookworm

# Security: Create a non-root user and group
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /Medilink

# Environment Variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    # Add the venv to PATH immediately
    PATH="/Medilink/.venv/bin:$PATH"

# 1. System Dependencies (Optional)
# If you need Postgres/MySQL headers, uncomment lines below:
# RUN apt-get update && apt-get install -y libpq-dev && rm -rf /var/lib/apt/lists/*

# 2. Copy Virtual Environment from Builder
# We pull the pre-built .venv from the previous stage
COPY --from=builder /Medilink/.venv /Medilink/.venv

# 3. Copy Application Code
# We do this LAST so code changes don't break the cache of previous steps
COPY . .

# 4. Permissions
# Change ownership of the directory to the non-root user
RUN chmod +x /Medilink/entrypoint.py

# Switch context to non-root user
USER appuser

# 5. Define Entrypoint
# Runs migrations/checks before starting the server
ENTRYPOINT ["python", "entrypoint.py"]

# 6. Start the Server
CMD ["gunicorn", "config.asgi:application", "-k", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8000"]