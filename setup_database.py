#!/usr/bin/env python3
"""
SQL Database Setup Script (Python version)
Supports: PostgreSQL and MySQL/MariaDB
Usage: python setup_database.py --type [postgres|mysql]
"""

import argparse
import os
import sys
import subprocess
from typing import Optional

# Configuration from environment variables or defaults
DEFAULT_CONFIG = {
    'postgres': {
        'db_name': os.getenv('DB_NAME', 'myapp_db'),
        'db_user': os.getenv('DB_USER', 'myapp_user'),
        'db_password': os.getenv('DB_PASSWORD', 'changeme123'),
        'db_host': os.getenv('DB_HOST', 'localhost'),
        'db_port': os.getenv('DB_PORT', '5432'),
    },
    'mysql': {
        'db_name': os.getenv('DB_NAME', 'myapp_db'),
        'db_user': os.getenv('DB_USER', 'myapp_user'),
        'db_password': os.getenv('DB_PASSWORD', 'changeme123'),
        'db_host': os.getenv('DB_HOST', 'localhost'),
        'db_port': os.getenv('DB_PORT', '3306'),
    }
}

class Colors:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'

def log_info(message: str):
    print(f"{Colors.GREEN}[INFO]{Colors.NC} {message}")

def log_warn(message: str):
    print(f"{Colors.YELLOW}[WARN]{Colors.NC} {message}")

def log_error(message: str):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}")

def run_command(command: list, check: bool = True, capture_output: bool = False) -> Optional[subprocess.CompletedProcess]:
    """Run a shell command"""
    try:
        result = subprocess.run(
            command,
            check=check,
            capture_output=capture_output,
            text=True
        )
        return result
    except subprocess.CalledProcessError as e:
        log_error(f"Command failed: {' '.join(command)}")
        log_error(f"Error: {e.stderr if capture_output else str(e)}")
        if check:
            sys.exit(1)
        return None

def setup_postgresql(config: dict):
    """Setup PostgreSQL database"""
    log_info("Setting up PostgreSQL database...")
    
    # Check if PostgreSQL is installed
    result = run_command(['which', 'psql'], check=False, capture_output=True)
    if result.returncode != 0:
        log_warn("PostgreSQL is not installed. Installing...")
        run_command(['sudo', 'apt-get', 'update'])
        run_command(['sudo', 'apt-get', 'install', '-y', 'postgresql', 'postgresql-contrib'])
    
    # Start PostgreSQL service
    log_info("Starting PostgreSQL service...")
    run_command(['sudo', 'systemctl', 'start', 'postgresql'])
    run_command(['sudo', 'systemctl', 'enable', 'postgresql'])
    
    # Create database and user
    log_info(f"Creating database '{config['db_name']}' and user '{config['db_user']}'...")
    
    sql_commands = f"""
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '{config['db_user']}') THEN
        CREATE USER {config['db_user']} WITH PASSWORD '{config['db_password']}';
    END IF;
END
$$;

SELECT 'CREATE DATABASE {config['db_name']}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '{config['db_name']}')\gexec

GRANT ALL PRIVILEGES ON DATABASE {config['db_name']} TO {config['db_user']};

\\c {config['db_name']}

GRANT ALL ON SCHEMA public TO {config['db_user']};
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO {config['db_user']};
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO {config['db_user']};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO {config['db_user']};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO {config['db_user']};
"""
    
    process = subprocess.Popen(
        ['sudo', '-u', 'postgres', 'psql'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = process.communicate(input=sql_commands)
    
    if process.returncode != 0:
        log_error(f"Failed to create database: {stderr}")
        sys.exit(1)
    
    log_info("PostgreSQL setup complete!")
    connection_string = f"postgresql://{config['db_user']}:{config['db_password']}@{config['db_host']}:{config['db_port']}/{config['db_name']}"
    log_info(f"Connection string: {connection_string}")

def setup_mysql(config: dict):
    """Setup MySQL/MariaDB database"""
    log_info("Setting up MySQL/MariaDB database...")
    
    # Check if MySQL is installed
    result = run_command(['which', 'mysql'], check=False, capture_output=True)
    if result.returncode != 0:
        log_warn("MySQL is not installed. Installing...")
        run_command(['sudo', 'apt-get', 'update'])
        run_command(['sudo', 'apt-get', 'install', '-y', 'mysql-server'])
    
    # Start MySQL service
    log_info("Starting MySQL service...")
    run_command(['sudo', 'systemctl', 'start', 'mysql'])
    run_command(['sudo', 'systemctl', 'enable', 'mysql'])
    
    # Create database and user
    log_info(f"Creating database '{config['db_name']}' and user '{config['db_user']}'...")
    
    sql_commands = f"""
CREATE DATABASE IF NOT EXISTS {config['db_name']} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '{config['db_user']}'@'localhost' IDENTIFIED BY '{config['db_password']}';
CREATE USER IF NOT EXISTS '{config['db_user']}'@'%' IDENTIFIED BY '{config['db_password']}';

GRANT ALL PRIVILEGES ON {config['db_name']}.* TO '{config['db_user']}'@'localhost';
GRANT ALL PRIVILEGES ON {config['db_name']}.* TO '{config['db_user']}'@'%';

FLUSH PRIVILEGES;
"""
    
    process = subprocess.Popen(
        ['sudo', 'mysql'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = process.communicate(input=sql_commands)
    
    if process.returncode != 0:
        log_error(f"Failed to create database: {stderr}")
        sys.exit(1)
    
    log_info("MySQL setup complete!")
    connection_string = f"mysql://{config['db_user']}:{config['db_password']}@{config['db_host']}:{config['db_port']}/{config['db_name']}"
    log_info(f"Connection string: {connection_string}")

def main():
    parser = argparse.ArgumentParser(
        description='SQL Database Setup Script',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python setup_database.py --type postgres
  python setup_database.py --type mysql --name mydb --user myuser --password mypass
  
Environment Variables:
  DB_NAME      Database name (default: myapp_db)
  DB_USER      Database user (default: myapp_user)
  DB_PASSWORD  Database password (default: changeme123)
  DB_HOST      Database host (default: localhost)
  DB_PORT      Database port (default: 5432 for postgres, 3306 for mysql)
        """
    )
    
    parser.add_argument(
        '--type',
        choices=['postgres', 'mysql'],
        default='postgres',
        help='Database type (default: postgres)'
    )
    parser.add_argument('--name', help='Database name (overrides DB_NAME env var)')
    parser.add_argument('--user', help='Database user (overrides DB_USER env var)')
    parser.add_argument('--password', help='Database password (overrides DB_PASSWORD env var)')
    parser.add_argument('--host', help='Database host (overrides DB_HOST env var)')
    parser.add_argument('--port', help='Database port (overrides DB_PORT env var)')
    
    args = parser.parse_args()
    
    # Get configuration
    config = DEFAULT_CONFIG[args.type].copy()
    if args.name:
        config['db_name'] = args.name
    if args.user:
        config['db_user'] = args.user
    if args.password:
        config['db_password'] = args.password
    if args.host:
        config['db_host'] = args.host
    if args.port:
        config['db_port'] = args.port
    
    log_info("SQL Database Setup Script")
    log_info("==========================")
    log_info(f"Database Type: {args.type}")
    log_info(f"Database Name: {config['db_name']}")
    log_info(f"Database User: {config['db_user']}")
    log_info("")
    
    if args.type == 'postgres':
        setup_postgresql(config)
    elif args.type == 'mysql':
        setup_mysql(config)
    
    log_info("")
    log_info("Setup completed successfully!")

if __name__ == '__main__':
    main()
