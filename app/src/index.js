const express = require('express');
const client = require('prom-client');
const { healthCheck } = require('./middleware/health');
const ordersRouter = require('./routes/orders');

const app = express();
const PORT = process.env.PORT || 3000;

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Durée des requêtes HTTP en secondes',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 1, 2, 5]
});
register.registerMetric(httpRequestDuration);

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, status_code: res.statusCode });
  });
  next();
});

app.use(express.json());

app.get('/health', healthCheck);
app.get('/version', (req, res) => {
  res.json({
    name: 'nexaretail-api',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    buildDate: process.env.BUILD_DATE || 'local',
    demo: 'M11 - Pipeline bout en bout - NexaRetail DevSecOps'
  });
});
app.use('/api/orders', ordersRouter);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(PORT, () => {
  console.log(`NexaRetail API démarrée sur le port ${PORT}`);
  console.log(`Health : http://localhost:${PORT}/health`);
  console.log(`Métriques : http://localhost:${PORT}/metrics`);
});
