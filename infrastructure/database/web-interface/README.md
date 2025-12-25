# NeoBase Database Web Manager

Simple web interface for managing PostgreSQL databases on remote Ubuntu servers.

## Quick Start

1. **Install dependencies:**
```bash
cd web-interface
npm install
```

2. **Start the server:**
```bash
npm start
```

3. **Open browser:**
Navigate to `http://localhost:3000`

## Features

- 📡 Test SSH connectivity to remote servers
- 🚀 Deploy database infrastructure to Ubuntu servers
- ➕ Create new PostgreSQL databases
- 🗑️ Delete databases
- 💾 Create backups
- 📋 List all active databases
- 🔌 View saved connection details

## Prerequisites

- Node.js 16+ installed on your MacBook
- SSH key-based authentication set up with your Ubuntu server
- Ubuntu server with sudo access

## Usage

1. Enter your server credentials (username and IP)
2. Test the connection
3. Deploy & setup the server (first time only)
4. Create databases as needed

All connection details are automatically saved and can be viewed in the interface.

## Security Note

Connection files with passwords are stored locally in `.remote-connections/` and should be kept secure.
