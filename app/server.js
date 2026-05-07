/**
 * Research Web Application
 * ========================
 * Comparative Analysis of Docker Containers vs Virtual Machines
 * Under Web Application Workloads
 *
 * Authors: Arham Jain, Ansh Mittal, Anuj Kumar
 * Institution: Chitkara University, Punjab, India
 *
 * Endpoints:
 * - GET /health          - Health check endpoint
 * - GET /api/static      - I/O-bound workload (50KB JSON payload)
 * - GET /api/compute     - CPU-bound workload (Fibonacci calculation)
 * - GET /api/system      - System information
 * - GET /api/metrics     - Application metrics
 */

const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

// Request counter for metrics
let requestCount = 0;
let startTime = Date.now();

// Middleware to count requests
app.use((req, res, next) => {
  requestCount++;
  next();
});

/**
 * Generate a ~50KB JSON payload for static endpoint testing
 * Simulates typical REST API response payload
 */
const generateStaticPayload = () => {
  const items = [];
  for (let i = 0; i < 500; i++) {
    items.push({
      id: i,
      uuid: `uuid-${i}-${Math.random().toString(36).substring(7)}`,
      name: `Item ${i}`,
      description: `This is a sample item description for item number ${i}. It contains text to increase payload size for I/O testing.`,
      timestamp: new Date().toISOString(),
      metadata: {
        category: `category-${i % 10}`,
        tags: [`tag-${i % 5}`, `tag-${(i + 1) % 5}`, `tag-${(i + 2) % 5}`],
        score: Math.random() * 100,
        active: i % 2 === 0
      }
    });
  }
  return items;
};

// Pre-generate static payload (cached for consistent benchmark)
const staticPayload = generateStaticPayload();

/**
 * Recursive Fibonacci calculation for CPU-bound testing
 * Intentionally inefficient to create measurable CPU load
 * @param {number} n - Fibonacci index
 * @returns {number} - Fibonacci number
 */
const fibonacci = (n) => {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
};

/**
 * Health Check Endpoint
 * Used for startup time measurement and load balancer health checks
 */
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    hostname: os.hostname()
  });
});

/**
 * Static Endpoint - I/O-bound Workload
 * Returns ~50KB JSON payload
 * Tests: Network throughput, disk I/O (if not cached), serialization
 */
app.get('/api/static', (req, res) => {
  res.json({
    success: true,
    data: staticPayload,
    metadata: {
      count: staticPayload.length,
      generatedAt: new Date().toISOString(),
      hostname: os.hostname()
    }
  });
});

/**
 * Compute Endpoint - CPU-bound Workload
 * Performs Fibonacci calculation (default n=35)
 * Tests: CPU utilization, process scheduling overhead
 */
app.get('/api/compute', (req, res) => {
  const n = Math.min(parseInt(req.query.n) || 35, 45); // Cap at 45 for safety
  const startTime = process.hrtime.bigint();

  const result = fibonacci(n);

  const endTime = process.hrtime.bigint();
  const executionTimeMs = Number(endTime - startTime) / 1_000_000;

  res.json({
    success: true,
    input: n,
    result: result,
    executionTimeMs: parseFloat(executionTimeMs.toFixed(3)),
    hostname: os.hostname()
  });
});

/**
 * System Information Endpoint
 * Returns host system details for verification
 */
app.get('/api/system', (req, res) => {
  const cpus = os.cpus();
  res.json({
    hostname: os.hostname(),
    platform: process.platform,
    arch: os.arch(),
    nodeVersion: process.version,
    cpus: {
      count: cpus.length,
      model: cpus[0]?.model || 'unknown',
      speed: cpus[0]?.speed || 0
    },
    memory: {
      total: os.totalmem(),
      free: os.freemem(),
      used: os.totalmem() - os.freemem(),
      usagePercent: ((1 - os.freemem() / os.totalmem()) * 100).toFixed(2)
    },
    uptime: {
      system: os.uptime(),
      process: process.uptime()
    },
    loadAverage: os.loadavg(),
    pid: process.pid
  });
});

/**
 * Application Metrics Endpoint
 * Returns request statistics for monitoring
 */
app.get('/api/metrics', (req, res) => {
  const uptimeSeconds = (Date.now() - startTime) / 1000;
  const memUsage = process.memoryUsage();

  res.json({
    requests: {
      total: requestCount,
      perSecond: (requestCount / uptimeSeconds).toFixed(2)
    },
    uptime: {
      seconds: uptimeSeconds,
      formatted: `${Math.floor(uptimeSeconds / 3600)}h ${Math.floor((uptimeSeconds % 3600) / 60)}m ${Math.floor(uptimeSeconds % 60)}s`
    },
    memory: {
      rss: memUsage.rss,
      heapTotal: memUsage.heapTotal,
      heapUsed: memUsage.heapUsed,
      external: memUsage.external
    },
    hostname: os.hostname()
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    path: req.path,
    availableEndpoints: [
      'GET /health',
      'GET /api/static',
      'GET /api/compute?n=35',
      'GET /api/system',
      'GET /api/metrics'
    ]
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log('='.repeat(60));
  console.log('Research Web Application - Docker vs VM Comparison');
  console.log('='.repeat(60));
  console.log(`Server running on port ${PORT}`);
  console.log(`Hostname: ${os.hostname()}`);
  console.log(`CPUs: ${os.cpus().length}`);
  console.log(`Memory: ${Math.round(os.totalmem() / 1024 / 1024)} MB`);
  console.log(`Node.js: ${process.version}`);
  console.log('='.repeat(60));
  console.log('Endpoints:');
  console.log(`  Health:  http://localhost:${PORT}/health`);
  console.log(`  Static:  http://localhost:${PORT}/api/static`);
  console.log(`  Compute: http://localhost:${PORT}/api/compute?n=35`);
  console.log(`  System:  http://localhost:${PORT}/api/system`);
  console.log(`  Metrics: http://localhost:${PORT}/api/metrics`);
  console.log('='.repeat(60));
});

module.exports = app;
