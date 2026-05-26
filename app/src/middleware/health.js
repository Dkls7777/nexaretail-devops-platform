const os = require('os');

const healthCheck = (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
    hostname: os.hostname(),
    version: process.env.APP_VERSION || '1.0.0'
  });
};

module.exports = { healthCheck };
