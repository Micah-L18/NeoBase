const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('public'));

// Path to scripts
const SCRIPTS_DIR = path.join(__dirname, '..', 'scripts');
const DEPLOY_SCRIPT = path.join(SCRIPTS_DIR, 'deploy-remote.sh');
const CONNECTIONS_DIR = path.join(__dirname, '..', '.remote-connections');

// Ensure connections directory exists
if (!fs.existsSync(CONNECTIONS_DIR)) {
    fs.mkdirSync(CONNECTIONS_DIR, { recursive: true });
}

// Helper function to execute shell commands
function executeCommand(command) {
    return new Promise((resolve, reject) => {
        exec(command, { maxBuffer: 1024 * 1024 * 10 }, (error, stdout, stderr) => {
            if (error) {
                reject({ error: error.message, stderr, stdout });
                return;
            }
            resolve({ stdout, stderr });
        });
    });
}

// API Routes

// Test server connection
app.post('/api/test-connection', async (req, res) => {
    const { serverUser, serverIp } = req.body;
    
    try {
        const command = `ssh -o ConnectTimeout=5 -o BatchMode=yes ${serverUser}@${serverIp} "echo 'Connected'"`;
        const result = await executeCommand(command);
        res.json({ success: true, message: 'Connection successful' });
    } catch (error) {
        res.status(400).json({ 
            success: false, 
            message: 'Connection failed. Make sure SSH keys are set up.',
            error: error.stderr || error.error
        });
    }
});

// Deploy setup to server
app.post('/api/deploy-setup', async (req, res) => {
    const { serverUser, serverIp } = req.body;
    
    try {
        const command = `"${DEPLOY_SCRIPT}" ${serverUser} ${serverIp} setup`;
        const result = await executeCommand(command);
        
        res.json({ 
            success: true, 
            message: 'Server setup complete',
            output: result.stdout 
        });
    } catch (error) {
        res.status(500).json({ 
            success: false, 
            message: 'Setup failed',
            error: error.stderr || error.error,
            output: error.stdout
        });
    }
});

// Create database
app.post('/api/create-database', async (req, res) => {
    const { serverUser, serverIp, userId, dbName } = req.body;
    
    if (!userId || !dbName) {
        return res.status(400).json({ 
            success: false, 
            message: 'User ID and database name are required' 
        });
    }
    
    try {
        const command = `"${DEPLOY_SCRIPT}" ${serverUser} ${serverIp} create-db ${userId} ${dbName}`;
        const result = await executeCommand(command);
        
        // Read connection file
        const connectionFile = path.join(CONNECTIONS_DIR, `${userId}_${serverIp}.json`);
        let connectionInfo = null;
        
        if (fs.existsSync(connectionFile)) {
            connectionInfo = JSON.parse(fs.readFileSync(connectionFile, 'utf8'));
        }
        
        res.json({ 
            success: true, 
            message: 'Database created successfully',
            output: result.stdout,
            connection: connectionInfo
        });
    } catch (error) {
        res.status(500).json({ 
            success: false, 
            message: 'Database creation failed',
            error: error.stderr || error.error,
            output: error.stdout
        });
    }
});

// Delete database
app.post('/api/delete-database', async (req, res) => {
    const { serverUser, serverIp, userId } = req.body;
    
    if (!userId) {
        return res.status(400).json({ 
            success: false, 
            message: 'User ID is required' 
        });
    }
    
    try {
        const command = `echo "yes" | "${DEPLOY_SCRIPT}" ${serverUser} ${serverIp} delete-db ${userId}`;
        const result = await executeCommand(command);
        
        res.json({ 
            success: true, 
            message: 'Database deleted successfully',
            output: result.stdout
        });
    } catch (error) {
        res.status(500).json({ 
            success: false, 
            message: 'Database deletion failed',
            error: error.stderr || error.error,
            output: error.stdout
        });
    }
});

// Backup database
app.post('/api/backup-database', async (req, res) => {
    const { serverUser, serverIp, userId } = req.body;
    
    try {
        const command = `"${DEPLOY_SCRIPT}" ${serverUser} ${serverIp} backup ${userId}`;
        const result = await executeCommand(command);
        
        res.json({ 
            success: true, 
            message: 'Backup completed successfully',
            output: result.stdout
        });
    } catch (error) {
        res.status(500).json({ 
            success: false, 
            message: 'Backup failed',
            error: error.stderr || error.error,
            output: error.stdout
        });
    }
});

// List databases
app.post('/api/list-databases', async (req, res) => {
    const { serverUser, serverIp } = req.body;
    
    try {
        const command = `"${DEPLOY_SCRIPT}" ${serverUser} ${serverIp} list`;
        const result = await executeCommand(command);
        
        res.json({ 
            success: true, 
            output: result.stdout
        });
    } catch (error) {
        res.status(500).json({ 
            success: false, 
            message: 'Failed to list databases',
            error: error.stderr || error.error,
            output: error.stdout
        });
    }
});

// Get stored connections
app.get('/api/connections', (req, res) => {
    try {
        const files = fs.readdirSync(CONNECTIONS_DIR);
        const connections = files
            .filter(f => f.endsWith('.json'))
            .map(f => {
                const data = JSON.parse(fs.readFileSync(path.join(CONNECTIONS_DIR, f), 'utf8'));
                return {
                    ...data,
                    server: f.replace(/.*_(.+)\.json$/, '$1')
                };
            });
        
        res.json({ success: true, connections });
    } catch (error) {
        res.status(500).json({ 
            success: false, 
            message: 'Failed to read connections',
            error: error.message 
        });
    }
});

// Start server
app.listen(PORT, () => {
    console.log(`\n🚀 NeoBase Database Manager running on http://localhost:${PORT}`);
    console.log(`\nOpen your browser and navigate to: http://localhost:${PORT}\n`);
});
