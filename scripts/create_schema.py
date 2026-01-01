#!/usr/bin/env python3
"""
Database Schema Creator Script
Creates table schemas in PostgreSQL or MySQL databases
Usage: python create_schema.py --type [postgres|mysql] --schema schema.sql
"""

import argparse
import os
import sys
from typing import List, Dict, Any

try:
    import psycopg2
    POSTGRES_AVAILABLE = True
except ImportError:
    POSTGRES_AVAILABLE = False

try:
    import mysql.connector
    MYSQL_AVAILABLE = True
except ImportError:
    MYSQL_AVAILABLE = False

# Configuration
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

# Example schemas
EXAMPLE_SCHEMAS = {
    'users': {
        'postgres': """
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
""",
        'mysql': """
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_email (email),
    INDEX idx_users_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
"""
    },
    'posts': {
        'postgres': """
CREATE TABLE IF NOT EXISTS posts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    status VARCHAR(20) DEFAULT 'draft',
    published_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_status ON posts(status);
CREATE INDEX idx_posts_published_at ON posts(published_at);
""",
        'mysql': """
CREATE TABLE IF NOT EXISTS posts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    status VARCHAR(20) DEFAULT 'draft',
    published_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_posts_user_id (user_id),
    INDEX idx_posts_status (status),
    INDEX idx_posts_published_at (published_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
"""
    },
    'comments': {
        'postgres': """
CREATE TABLE IF NOT EXISTS comments (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    parent_id INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE
);

CREATE INDEX idx_comments_post_id ON comments(post_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_comments_parent_id ON comments(parent_id);
""",
        'mysql': """
CREATE TABLE IF NOT EXISTS comments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    parent_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE CASCADE,
    INDEX idx_comments_post_id (post_id),
    INDEX idx_comments_user_id (user_id),
    INDEX idx_comments_parent_id (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
"""
    }
}

class Colors:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'

def log_info(message: str):
    print(f"{Colors.GREEN}[INFO]{Colors.NC} {message}")

def log_warn(message: str):
    print(f"{Colors.YELLOW}[WARN]{Colors.NC} {message}")

def log_error(message: str):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}")

def log_success(message: str):
    print(f"{Colors.BLUE}[SUCCESS]{Colors.NC} {message}")

class SchemaCreator:
    """Base class for schema creation"""
    
    def __init__(self, config: dict, db_type: str):
        self.config = config
        self.db_type = db_type
        self.connection = None
        self.cursor = None
    
    def connect(self):
        """Establish database connection - to be implemented by subclasses"""
        raise NotImplementedError
    
    def execute_sql(self, sql: str):
        """Execute SQL statements"""
        try:
            # Split SQL file into individual statements
            statements = [s.strip() for s in sql.split(';') if s.strip()]
            
            for statement in statements:
                if statement:
                    log_info(f"Executing: {statement[:80]}...")
                    self.cursor.execute(statement)
            
            self.connection.commit()
            log_success("Schema created successfully!")
            return True
        except Exception as e:
            log_error(f"Failed to execute SQL: {e}")
            self.connection.rollback()
            return False
    
    def close(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
            log_info("Database connection closed")

class PostgresSchemaCreator(SchemaCreator):
    """PostgreSQL schema creator"""
    
    def __init__(self, config: dict):
        super().__init__(config, 'postgres')
        if not POSTGRES_AVAILABLE:
            log_error("psycopg2 is not installed. Install it with: pip install psycopg2-binary")
            sys.exit(1)
    
    def connect(self):
        """Establish database connection"""
        try:
            self.connection = psycopg2.connect(
                dbname=self.config['db_name'],
                user=self.config['db_user'],
                password=self.config['db_password'],
                host=self.config['db_host'],
                port=self.config['db_port']
            )
            self.cursor = self.connection.cursor()
            log_info(f"Connected to PostgreSQL database: {self.config['db_name']}")
        except Exception as e:
            log_error(f"Failed to connect to PostgreSQL: {e}")
            sys.exit(1)

class MySQLSchemaCreator(SchemaCreator):
    """MySQL schema creator"""
    
    def __init__(self, config: dict):
        super().__init__(config, 'mysql')
        if not MYSQL_AVAILABLE:
            log_error("mysql-connector-python is not installed. Install it with: pip install mysql-connector-python")
            sys.exit(1)
    
    def connect(self):
        """Establish database connection"""
        try:
            self.connection = mysql.connector.connect(
                database=self.config['db_name'],
                user=self.config['db_user'],
                password=self.config['db_password'],
                host=self.config['db_host'],
                port=self.config['db_port']
            )
            self.cursor = self.connection.cursor()
            log_info(f"Connected to MySQL database: {self.config['db_name']}")
        except Exception as e:
            log_error(f"Failed to connect to MySQL: {e}")
            sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description='Database Schema Creator Script',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Create schema from file
  python create_schema.py --type postgres --schema schema.sql
  
  # Create example schemas
  python create_schema.py --type postgres --example users,posts,comments
  
  # Generate example schema file
  python create_schema.py --type mysql --generate-example > example_schema.sql
  
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
        required=True,
        help='Database type'
    )
    parser.add_argument('--schema', help='Path to SQL schema file')
    parser.add_argument('--example', help='Create example tables (comma-separated: users,posts,comments)')
    parser.add_argument('--generate-example', action='store_true', help='Generate example schema SQL and print to stdout')
    parser.add_argument('--name', help='Database name (overrides DB_NAME env var)')
    parser.add_argument('--user', help='Database user (overrides DB_USER env var)')
    parser.add_argument('--password', help='Database password (overrides DB_PASSWORD env var)')
    parser.add_argument('--host', help='Database host (overrides DB_HOST env var)')
    parser.add_argument('--port', help='Database port (overrides DB_PORT env var)')
    
    args = parser.parse_args()
    
    # Handle generate-example without database connection
    if args.generate_example:
        print(f"-- Example Schema for {args.type.upper()}")
        print(f"-- Generated on {os.popen('date').read().strip()}")
        print()
        for table_name, schemas in EXAMPLE_SCHEMAS.items():
            print(f"-- Table: {table_name}")
            print(schemas[args.type])
            print()
        return
    
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
    
    # Create schema creator instance
    if args.type == 'postgres':
        creator = PostgresSchemaCreator(config)
    else:
        creator = MySQLSchemaCreator(config)
    
    try:
        # Connect to database
        creator.connect()
        
        # Execute requested operation
        if args.schema:
            # Read SQL from file
            if not os.path.exists(args.schema):
                log_error(f"Schema file not found: {args.schema}")
                sys.exit(1)
            
            with open(args.schema, 'r') as f:
                sql = f.read()
            
            log_info(f"Creating schema from file: {args.schema}")
            creator.execute_sql(sql)
        
        elif args.example:
            # Create example tables
            tables = [t.strip() for t in args.example.split(',')]
            
            for table in tables:
                if table not in EXAMPLE_SCHEMAS:
                    log_warn(f"Unknown example table: {table}")
                    continue
                
                log_info(f"Creating example table: {table}")
                sql = EXAMPLE_SCHEMAS[table][args.type]
                creator.execute_sql(sql)
        
        else:
            log_error("Please specify --schema or --example")
            parser.print_help()
    
    finally:
        creator.close()

if __name__ == '__main__':
    main()
