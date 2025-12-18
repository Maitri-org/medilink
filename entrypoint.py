#!/usr/bin/env python3
# ==========================================
# ENTRYPOINT SCRIPT FOR DOCKER CONTAINER
# for MEDILINK APPLICATION
# genreated: 17th december 2023
# author: kulkarni vedant manoj
# email: vedantkulkarni.20.000@gmail.com
# discription:
# This script waits for dependent services
# like the database and redis to be available
# before starting the main application server
# using Gunicorn with Uvicorn workers.
# ==========================================
import os
import sys
import time
import socket
import subprocess

def wait_for_service(host, port, service_name, timeout=30):
    print(f"🔍 Waiting for {service_name} at {host}:{port}...")
    start_time = time.time()
    while True:
        try:
            with socket.create_connection((host, int(port)), timeout=1):
                print(f"✅ Service {service_name} is ready.")
                return True
        except (OSError, ConnectionRefusedError):
            if time.time() - start_time > timeout:
                print(f"❌ Timeout waiting for {service_name} at {host}:{port}")
                return False
            time.sleep(1)

def run_command(command):
    """Run command using the container's Python (which has all packages installed)"""
    # In Docker, just use 'python' - dependencies are installed globally
    python_exec = sys.executable  # This is /usr/local/bin/python in your container
    
    # Replace generic 'python' with the executable
    if command[0] in ['python', 'python3']:
        command[0] = python_exec
    
    cmd_str = ' '.join(command)
    print(f"🔄 Running: {cmd_str}")
    
    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError:
        print(f"❌ Command failed: {cmd_str}")
        sys.exit(1)

def main():
    db_host = os.environ.get('POSTGRES_HOST', 'medilink-db')
    db_port = os.environ.get('POSTGRES_PORT', '5432')
    redis_host = os.environ.get('REDIS_HOST', 'medilink-redis')
    redis_port = os.environ.get('REDIS_PORT', '6379')
    
    if not wait_for_service(db_host, db_port, "Postgres"):
        sys.exit(1)
    
    if not wait_for_service(redis_host, redis_port, "Redis"):
        sys.exit(1)
    
    # Run Migrations
    run_command(['python', 'manage.py', 'migrate'])
    
    # Start Server
    if len(sys.argv) > 1:
        os.execvp(sys.argv[1], sys.argv[1:])
    else:
        print("🚀 Starting Server...")
        # Use gunicorn directly (it's installed globally in the container)
        os.execvp("gunicorn", [
            "gunicorn",
            "config.asgi:application", 
            "-k", "uvicorn.workers.UvicornWorker", 
            "--bind", "0.0.0.0:8000"
        ])

if __name__ == "__main__":
    main()