# Research Web Application

Web application for **"Comparative Analysis of Resource Utilization Between Docker Containers and Virtual Machines Under Web Application Workloads"**

## Quick Start

### Local Development
```bash
npm install
npm start
```

### Docker
```bash
# Build and run
docker build -t research-app .
docker run -p 3000:3000 research-app

# With resource limits (as per research paper)
docker run --cpus=4 --memory=8g -p 3000:3000 research-app

# Using docker-compose
docker-compose up
```

## Endpoints

| Endpoint | Type | Description |
|----------|------|-------------|
| `GET /health` | Health Check | Returns server status |
| `GET /api/static` | I/O-bound | Returns ~50KB JSON payload |
| `GET /api/compute?n=35` | CPU-bound | Fibonacci calculation |
| `GET /api/system` | Info | System information |
| `GET /api/metrics` | Metrics | Request statistics |

## Benchmark Workloads

### Static Endpoint (I/O-bound)
- Returns ~50KB JSON payload
- Tests network throughput and serialization
- Minimal CPU usage

### Compute Endpoint (CPU-bound)
- Calculates Fibonacci(n) recursively
- Default n=35 (as per research paper)
- Tests CPU utilization and scheduling

## Testing
```bash
# Start server first
npm start

# Run tests (in another terminal)
npm test
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | Server port |
| `NODE_ENV` | development | Environment |
