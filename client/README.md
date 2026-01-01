# Database Viewer - Express Web App

A simple web interface to view and query remote PostgreSQL and MySQL databases.

## Features

- 🔌 Connect to remote PostgreSQL or MySQL databases
- 📊 View all tables in the database
- 🔍 Browse table data with pagination
- 📋 View table structure and schema
- ⚡ Execute custom SQL queries
- 🎨 Clean, modern UI with real-time updates

## Installation

```bash
cd client
npm install
```

## Usage

### Start the Server

```bash
npm start
```

Or for development with auto-reload:

```bash
npm run dev
```

### Access the Application

Open your browser and navigate to:
```
http://localhost:3000
```

## How to Use

1. **Enter Connection Details**
   - Select database type (PostgreSQL or MySQL)
   - Enter server IP address (e.g., 192.168.0.221)
   - Enter port (default: 5432 for PostgreSQL, 3306 for MySQL)
   - Enter database name, username, and password
   - Click "Connect to Database"

2. **Browse Tables**
   - Once connected, you'll see a list of all tables
   - Click on any table to view its data
   - Switch between "Data" and "Structure" tabs

3. **Execute Custom Queries**
   - Click the "Custom Query" tab
   - Write your SQL query
   - Click "Execute Query" to see results

4. **Disconnect**
   - Click the "Disconnect" button when done

## Configuration

The server runs on port 3000 by default. You can change this by setting the PORT environment variable:

```bash
PORT=8080 npm start
```

## API Endpoints

- `POST /api/connect` - Test database connection
- `GET /api/tables/:connectionId` - List all tables
- `GET /api/table/:connectionId/:tableName` - Get table structure
- `GET /api/data/:connectionId/:tableName` - Get table data
- `POST /api/query/:connectionId` - Execute custom query
- `POST /api/disconnect/:connectionId` - Close connection

## Requirements

- Node.js 14 or higher
- PostgreSQL client libraries (for PostgreSQL connections)
- MySQL client libraries (for MySQL connections)

## Security Notes

⚠️ **Important**: This is a simple viewer tool for development/internal use.

For production use, consider:
- Adding authentication/authorization
- Using environment variables for sensitive data
- Implementing rate limiting
- Adding SQL injection protection
- Using HTTPS
- Implementing proper session management

## Troubleshooting

### Cannot Connect to Database

Make sure:
1. The database server is running
2. The server is configured to accept remote connections
3. Firewall allows the database port (5432 for PostgreSQL, 3306 for MySQL)
4. Credentials are correct

See `../REMOTE_CONNECTION_GUIDE.md` for detailed setup instructions.

### Port Already in Use

If port 3000 is already in use:
```bash
PORT=3001 npm start
```

## Screenshot

The application features:
- Connection form with all database parameters
- Table list with stats
- Data viewer with pagination
- Structure viewer
- Custom query editor with results display

## License

MIT
