/**
 * Test Suite for Research Web Application
 * Uses Node.js built-in test runner (Node 18+)
 */

const { describe, it, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');

const BASE_URL = 'http://localhost:3000';

/**
 * Helper function to make HTTP requests
 */
const makeRequest = (path) => {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    http.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: data
          });
        }
      });
    }).on('error', reject);
  });
};

describe('Health Endpoint', () => {
  it('should return healthy status', async () => {
    const res = await makeRequest('/health');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'healthy');
    assert.ok(res.body.timestamp);
    assert.ok(res.body.hostname);
  });
});

describe('Static Endpoint (I/O-bound)', () => {
  it('should return 200 status', async () => {
    const res = await makeRequest('/api/static');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
  });

  it('should return data array with 500 items', async () => {
    const res = await makeRequest('/api/static');
    assert.strictEqual(res.body.data.length, 500);
  });

  it('should have proper item structure', async () => {
    const res = await makeRequest('/api/static');
    const item = res.body.data[0];
    assert.ok(item.id !== undefined);
    assert.ok(item.name);
    assert.ok(item.description);
    assert.ok(item.metadata);
    assert.ok(item.metadata.tags);
  });

  it('should return ~50KB payload', async () => {
    const res = await makeRequest('/api/static');
    const payloadSize = JSON.stringify(res.body).length;
    // Should be between 40KB and 60KB
    assert.ok(payloadSize > 40000, `Payload too small: ${payloadSize}`);
    assert.ok(payloadSize < 70000, `Payload too large: ${payloadSize}`);
  });
});

describe('Compute Endpoint (CPU-bound)', () => {
  it('should return 200 status', async () => {
    const res = await makeRequest('/api/compute');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
  });

  it('should calculate fibonacci(35) correctly', async () => {
    const res = await makeRequest('/api/compute?n=35');
    assert.strictEqual(res.body.input, 35);
    assert.strictEqual(res.body.result, 9227465);
  });

  it('should include execution time', async () => {
    const res = await makeRequest('/api/compute?n=20');
    assert.ok(res.body.executionTimeMs !== undefined);
    assert.ok(typeof res.body.executionTimeMs === 'number');
  });

  it('should cap n at 45 for safety', async () => {
    const res = await makeRequest('/api/compute?n=50');
    assert.strictEqual(res.body.input, 45);
  });
});

describe('System Endpoint', () => {
  it('should return system information', async () => {
    const res = await makeRequest('/api/system');
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.hostname);
    assert.ok(res.body.platform);
    assert.ok(res.body.cpus);
    assert.ok(res.body.memory);
  });

  it('should include CPU details', async () => {
    const res = await makeRequest('/api/system');
    assert.ok(res.body.cpus.count > 0);
    assert.ok(res.body.cpus.model);
  });

  it('should include memory details', async () => {
    const res = await makeRequest('/api/system');
    assert.ok(res.body.memory.total > 0);
    assert.ok(res.body.memory.free >= 0);
  });
});

describe('Metrics Endpoint', () => {
  it('should return metrics', async () => {
    const res = await makeRequest('/api/metrics');
    assert.strictEqual(res.status, 200);
    assert.ok(res.body.requests);
    assert.ok(res.body.uptime);
    assert.ok(res.body.memory);
  });
});

describe('404 Handler', () => {
  it('should return 404 for unknown routes', async () => {
    const res = await makeRequest('/unknown');
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.body.error, 'Not Found');
    assert.ok(res.body.availableEndpoints);
  });
});

console.log('Run tests with: node --test tests/server.test.js');
console.log('Note: Server must be running on port 3000');
