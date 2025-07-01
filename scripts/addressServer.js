const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const app = express();
const port = 3011; // Different port to avoid conflicts

// Configure CORS options to allow requests from UI
const corsOptions = {
    origin: ['http://localhost:3000', 'http://localhost:3001', 'http://localhost:5173'], // Common React/Vite ports
    optionsSuccessStatus: 200,
    credentials: true
};

// Apply CORS middleware
app.use(cors(corsOptions));

// Path to the addresses file (will be created by deployment script)
const addressesPath = path.join(__dirname, 'deployedAddresses.json');

// Endpoint to get deployed contract addresses
app.get('/api/contract-addresses', async (req, res) => {
    try {
        if (!fs.existsSync(addressesPath)) {
            return res.status(404).json({ error: 'No deployed addresses found. Run deployment script first.' });
        }
        
        const data = fs.readFileSync(addressesPath, 'utf-8');
        const addresses = JSON.parse(data);
        
        // Add chain ID and deployment timestamp
        const response = {
            chainId: 31337, // Anvil's default chain ID
            ...addresses
        };
        
        res.json(response);
    } catch (error) {
        console.error('Failed to read addresses:', error);
        res.status(500).json({ error: 'Error reading deployed addresses' });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'ok', port, addressesPath });
});

app.listen(port, () => {
    console.log(`\n🚀 Address server running on http://localhost:${port}`);
    console.log(`📍 Contract addresses endpoint: http://localhost:${port}/api/contract-addresses`);
    console.log(`❤️  Health check: http://localhost:${port}/health\n`);
});