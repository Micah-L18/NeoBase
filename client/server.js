const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const { Client: PgClient } = require('pg');
const mysql = require('mysql2/promise');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('public'));

// Store active connections (in production, use proper session management)
const connections = new Map();

// PostgreSQL functions
async function connectPostgres(config) {
  const client = new PgClient({
    host: config.host,
    port: config.port || 5432,
    database: config.database,
    user: config.user,
    password: config.password,
  });
  
  await client.connect();
  return client;
}

async function postgresListTables(client) {
  const result = await client.query(`
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    ORDER BY table_name;
  `);
  return result.rows.map(row => row.table_name);
}

async function postgresDescribeTable(client, tableName) {
  const result = await client.query(`
    SELECT 
      column_name,
      data_type,
      character_maximum_length,
      is_nullable,
      column_default
    FROM information_schema.columns
    WHERE table_name = $1
    ORDER BY ordinal_position;
  `, [tableName]);
  return result.rows;
}

async function postgresQuery(client, query) {
  const result = await client.query(query);
  return {
    rows: result.rows,
    rowCount: result.rowCount,
    fields: result.fields ? result.fields.map(f => f.name) : []
  };
}

// MySQL functions
async function connectMySQL(config) {
  const connection = await mysql.createConnection({
    host: config.host,
    port: config.port || 3306,
    database: config.database,
    user: config.user,
    password: config.password,
  });
  
  return connection;
}

async function mysqlListTables(connection) {
  const [rows] = await connection.query('SHOW TABLES');
  const key = Object.keys(rows[0])[0];
  return rows.map(row => row[key]);
}

async function mysqlDescribeTable(connection, tableName) {
  const [rows] = await connection.query(`DESCRIBE ${tableName}`);
  return rows;
}

async function mysqlQuery(connection, query) {
  const [rows, fields] = await connection.query(query);
  return {
    rows: rows,
    rowCount: rows.length,
    fields: fields ? fields.map(f => f.name) : []
  };
}

// API Routes

// Test connection
app.post('/api/connect', async (req, res) => {
  try {
    const { type, host, port, database, user, password } = req.body;
    
    let connection;
    if (type === 'postgres') {
      connection = await connectPostgres({ host, port, database, user, password });
    } else if (type === 'mysql') {
      connection = await connectMySQL({ host, port, database, user, password });
    } else {
      return res.status(400).json({ error: 'Invalid database type' });
    }
    
    // Store connection with a unique ID
    const connectionId = Date.now().toString();
    connections.set(connectionId, { type, connection });
    
    res.json({ 
      success: true, 
      connectionId,
      message: `Connected to ${type} database successfully`
    });
  } catch (error) {
    res.status(500).json({ 
      error: error.message,
      details: 'Make sure the database is configured to accept remote connections'
    });
  }
});

// List tables
app.get('/api/tables/:connectionId', async (req, res) => {
  try {
    const { connectionId } = req.params;
    const conn = connections.get(connectionId);
    
    if (!conn) {
      return res.status(404).json({ error: 'Connection not found' });
    }
    
    let tables;
    if (conn.type === 'postgres') {
      tables = await postgresListTables(conn.connection);
    } else {
      tables = await mysqlListTables(conn.connection);
    }
    
    res.json({ tables });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Describe table
app.get('/api/table/:connectionId/:tableName', async (req, res) => {
  try {
    const { connectionId, tableName } = req.params;
    const conn = connections.get(connectionId);
    
    if (!conn) {
      return res.status(404).json({ error: 'Connection not found' });
    }
    
    let structure;
    if (conn.type === 'postgres') {
      structure = await postgresDescribeTable(conn.connection, tableName);
    } else {
      structure = await mysqlDescribeTable(conn.connection, tableName);
    }
    
    res.json({ structure });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get table relationships
app.get('/api/relationships/:connectionId', async (req, res) => {
  try {
    const { connectionId } = req.params;
    const conn = connections.get(connectionId);
    
    if (!conn) {
      return res.status(404).json({ error: 'Connection not found' });
    }
    
    let relationships;
    if (conn.type === 'postgres') {
      const result = await conn.connection.query(`
        SELECT
          tc.table_name AS from_table,
          kcu.column_name AS from_column,
          ccu.table_name AS to_table,
          ccu.column_name AS to_column,
          tc.constraint_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'public'
        ORDER BY tc.table_name;
      `);
      relationships = result.rows;
    } else {
      const [rows] = await conn.connection.query(`
        SELECT
          TABLE_NAME AS from_table,
          COLUMN_NAME AS from_column,
          REFERENCED_TABLE_NAME AS to_table,
          REFERENCED_COLUMN_NAME AS to_column,
          CONSTRAINT_NAME AS constraint_name
        FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
        WHERE REFERENCED_TABLE_NAME IS NOT NULL
          AND TABLE_SCHEMA = DATABASE()
        ORDER BY TABLE_NAME;
      `);
      relationships = rows;
    }
    
    res.json({ relationships });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Query data from table
app.get('/api/data/:connectionId/:tableName', async (req, res) => {
  try {
    const { connectionId, tableName } = req.params;
    const { limit = 100, offset = 0 } = req.query;
    const conn = connections.get(connectionId);
    
    if (!conn) {
      return res.status(404).json({ error: 'Connection not found' });
    }
    
    const query = `SELECT * FROM ${tableName} LIMIT ${limit} OFFSET ${offset}`;
    
    let result;
    if (conn.type === 'postgres') {
      result = await postgresQuery(conn.connection, query);
    } else {
      result = await mysqlQuery(conn.connection, query);
    }
    
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Custom query
app.post('/api/query/:connectionId', async (req, res) => {
  try {
    const { connectionId } = req.params;
    const { query } = req.body;
    const conn = connections.get(connectionId);
    
    if (!conn) {
      return res.status(404).json({ error: 'Connection not found' });
    }
    
    let result;
    if (conn.type === 'postgres') {
      result = await postgresQuery(conn.connection, query);
    } else {
      result = await mysqlQuery(conn.connection, query);
    }
    
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Disconnect
app.post('/api/disconnect/:connectionId', async (req, res) => {
  try {
    const { connectionId } = req.params;
    const conn = connections.get(connectionId);
    
    if (!conn) {
      return res.status(404).json({ error: 'Connection not found' });
    }
    
    if (conn.type === 'postgres') {
      await conn.connection.end();
    } else {
      await conn.connection.end();
    }
    
    connections.delete(connectionId);
    
    res.json({ success: true, message: 'Disconnected successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', activeConnections: connections.size });
});

// Start server
app.listen(PORT, () => {
  console.log(`🗄️  Database Viewer running on http://localhost:${PORT}`);
  console.log(`📊 Open your browser and navigate to http://localhost:${PORT}`);
});

// Cleanup on exit
process.on('SIGINT', async () => {
  console.log('\nClosing all database connections...');
  for (const [id, conn] of connections.entries()) {
    try {
      if (conn.type === 'postgres') {
        await conn.connection.end();
      } else {
        await conn.connection.end();
      }
    } catch (error) {
      console.error(`Error closing connection ${id}:`, error.message);
    }
  }
  process.exit(0);
});
