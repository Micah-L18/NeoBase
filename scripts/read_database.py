#!/usr/bin/env python3
"""
Database Reader Script
Connects to and reads data from PostgreSQL or MySQL databases
Usage: python read_database.py --type [postgres|mysql] --query "SELECT * FROM users"
"""

import argparse
import os
import sys
from typing import List, Dict, Any

try:
    import psycopg2
    import psycopg2.extras
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

def log_data(message: str):
    print(f"{Colors.BLUE}[DATA]{Colors.NC} {message}")

class PostgresReader:
    """PostgreSQL database reader"""
    
    def __init__(self, config: dict):
        if not POSTGRES_AVAILABLE:
            log_error("psycopg2 is not installed. Install it with: pip install psycopg2-binary")
            sys.exit(1)
        
        self.config = config
        self.connection = None
        self.cursor = None
    
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
            self.cursor = self.connection.cursor(cursor_factory=psycopg2.extras.DictCursor)
            log_info(f"Connected to PostgreSQL database: {self.config['db_name']}")
        except Exception as e:
            log_error(f"Failed to connect to PostgreSQL: {e}")
            sys.exit(1)
    
    def execute_query(self, query: str) -> List[Dict[str, Any]]:
        """Execute a SELECT query and return results"""
        try:
            self.cursor.execute(query)
            if query.strip().upper().startswith('SELECT'):
                results = self.cursor.fetchall()
                return [dict(row) for row in results]
            else:
                self.connection.commit()
                return []
        except Exception as e:
            log_error(f"Query execution failed: {e}")
            return []
    
    def list_tables(self) -> List[str]:
        """List all tables in the database"""
        query = """
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            ORDER BY table_name;
        """
        results = self.execute_query(query)
        return [row['table_name'] for row in results]
    
    def describe_table(self, table_name: str) -> List[Dict[str, Any]]:
        """Get table structure"""
        query = f"""
            SELECT 
                column_name,
                data_type,
                character_maximum_length,
                is_nullable,
                column_default
            FROM information_schema.columns
            WHERE table_name = '{table_name}'
            ORDER BY ordinal_position;
        """
        return self.execute_query(query)
    
    def close(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
            log_info("Database connection closed")

class MySQLReader:
    """MySQL database reader"""
    
    def __init__(self, config: dict):
        if not MYSQL_AVAILABLE:
            log_error("mysql-connector-python is not installed. Install it with: pip install mysql-connector-python")
            sys.exit(1)
        
        self.config = config
        self.connection = None
        self.cursor = None
    
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
            self.cursor = self.connection.cursor(dictionary=True)
            log_info(f"Connected to MySQL database: {self.config['db_name']}")
        except Exception as e:
            log_error(f"Failed to connect to MySQL: {e}")
            sys.exit(1)
    
    def execute_query(self, query: str) -> List[Dict[str, Any]]:
        """Execute a SELECT query and return results"""
        try:
            self.cursor.execute(query)
            if query.strip().upper().startswith('SELECT'):
                results = self.cursor.fetchall()
                return results
            else:
                self.connection.commit()
                return []
        except Exception as e:
            log_error(f"Query execution failed: {e}")
            return []
    
    def list_tables(self) -> List[str]:
        """List all tables in the database"""
        query = "SHOW TABLES;"
        results = self.execute_query(query)
        if results:
            key = list(results[0].keys())[0]
            return [row[key] for row in results]
        return []
    
    def describe_table(self, table_name: str) -> List[Dict[str, Any]]:
        """Get table structure"""
        query = f"DESCRIBE {table_name};"
        return self.execute_query(query)
    
    def close(self):
        """Close database connection"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
            log_info("Database connection closed")

def print_results(results: List[Dict[str, Any]], format_type: str = 'table'):
    """Print query results in formatted output"""
    if not results:
        log_warn("No results returned")
        return
    
    if format_type == 'json':
        import json
        print(json.dumps(results, indent=2, default=str))
    else:
        # Print as table
        if results:
            headers = list(results[0].keys())
            
            # Calculate column widths
            col_widths = {h: len(h) for h in headers}
            for row in results:
                for header in headers:
                    val_len = len(str(row.get(header, '')))
                    col_widths[header] = max(col_widths[header], val_len)
            
            # Print header
            header_line = " | ".join(h.ljust(col_widths[h]) for h in headers)
            print("\n" + header_line)
            print("-" * len(header_line))
            
            # Print rows
            for row in results:
                row_line = " | ".join(str(row.get(h, '')).ljust(col_widths[h]) for h in headers)
                print(row_line)
            
            print(f"\n{len(results)} row(s) returned\n")

def main():
    parser = argparse.ArgumentParser(
        description='Database Reader Script',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # List all tables
  python read_database.py --type postgres --list-tables
  
  # Describe a table
  python read_database.py --type postgres --describe users
  
  # Execute custom query
  python read_database.py --type postgres --query "SELECT * FROM users LIMIT 10"
  
  # Output as JSON
  python read_database.py --type mysql --query "SELECT * FROM users" --format json
  
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
    parser.add_argument('--query', help='SQL query to execute')
    parser.add_argument('--list-tables', action='store_true', help='List all tables in database')
    parser.add_argument('--describe', help='Describe table structure')
    parser.add_argument('--format', choices=['table', 'json'], default='table', help='Output format')
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
    
    # Create reader instance
    if args.type == 'postgres':
        reader = PostgresReader(config)
    else:
        reader = MySQLReader(config)
    
    try:
        # Connect to database
        reader.connect()
        
        # Execute requested operation
        if args.list_tables:
            tables = reader.list_tables()
            if tables:
                log_info(f"Tables in database '{config['db_name']}':")
                for table in tables:
                    print(f"  - {table}")
            else:
                log_warn("No tables found in database")
        
        elif args.describe:
            results = reader.describe_table(args.describe)
            if results:
                log_info(f"Structure of table '{args.describe}':")
                print_results(results, args.format)
            else:
                log_warn(f"Table '{args.describe}' not found")
        
        elif args.query:
            results = reader.execute_query(args.query)
            if results:
                print_results(results, args.format)
            elif not args.query.strip().upper().startswith('SELECT'):
                log_info("Query executed successfully")
        
        else:
            log_error("Please specify --query, --list-tables, or --describe")
            parser.print_help()
    
    finally:
        reader.close()

if __name__ == '__main__':
    main()
