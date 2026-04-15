# Nova Backend — Deployment Guide

## Overview

This guide covers deploying Nova backend to production and staging environments.

## Pre-Deployment

### 1. Verify Local Setup

```bash
# Install dependencies
npm install

# Run linting
npm run lint

# Run tests
npm run test

# Build project
npm run build

# Check build output
ls -la dist/
```

### 2. Environment Configuration

Create `.env.production` with:

```
DATABASE_URL=postgresql://user:password@host:5432/nova_prod
JWT_SECRET=<generate-secure-32-char-key>
JWT_REFRESH_SECRET=<generate-secure-32-char-key>
NODE_ENV=production
LOG_LEVEL=warn
PORT=3000
HOST=0.0.0.0

# Optional: CloudFlare R2 for assets
R2_ACCOUNT_ID=xxx
R2_ACCESS_KEY_ID=xxx
R2_SECRET_ACCESS_KEY=xxx
R2_BUCKET_NAME=nova-assets
R2_PUBLIC_URL=https://assets.nova-app.com

# Optional: OpenAI integration
OPENAI_API_KEY=xxx
OPENAI_OAUTH_CLIENT_ID=xxx
OPENAI_OAUTH_CLIENT_SECRET=xxx
OPENAI_OAUTH_REDIRECT_URI=https://api.nova-app.com/api/v1/oauth/callback
```

### 3. Database Preparation

#### Option A: Cloud PostgreSQL (Recommended)

1. Set up managed PostgreSQL (AWS RDS, Azure Database, Heroku, etc.)
2. Update `DATABASE_URL` to cloud instance
3. Ensure backups are configured
4. Set up connection pooling (PgBouncer recommended)

#### Option B: Self-Hosted

1. Provision PostgreSQL 16+ server
2. Create database and user
3. Configure backups and replication
4. Set up monitoring

### 4. Generate Secure Secrets

```bash
# Generate JWT secrets (generate 32+ random chars)
openssl rand -base64 32

# Example:
# JWT_SECRET=abc123xyz789def456ghi789jkl012mno
# JWT_REFRESH_SECRET=xyz789def456ghi789jkl012mno345pqr
```

## Deployment Methods

### Method 1: Docker (Recommended)

#### Build Image

```bash
# Build for production
docker build -t nova-api:0.1.0 .

# Tag for registry
docker tag nova-api:0.1.0 your-registry.com/nova-api:0.1.0

# Push to registry
docker push your-registry.com/nova-api:0.1.0
```

#### Run Container

```bash
# Using docker run
docker run -d \
  --name nova-api \
  -p 3000:3000 \
  --env-file .env.production \
  your-registry.com/nova-api:0.1.0

# Using docker-compose
docker-compose -f docker-compose.prod.yml up -d
```

#### Production docker-compose.yml

```yaml
version: '3.9'

services:
  api:
    image: your-registry.com/nova-api:0.1.0
    container_name: nova-api
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
      DATABASE_URL: ${DATABASE_URL}
      JWT_SECRET: ${JWT_SECRET}
      JWT_REFRESH_SECRET: ${JWT_REFRESH_SECRET}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/v1/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - nova-network
    depends_on:
      - postgres

  postgres:
    image: postgres:16-alpine
    container_name: nova-postgres
    environment:
      POSTGRES_USER: nova
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: nova_prod
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nova"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - nova-network

volumes:
  postgres_data:
    driver: local

networks:
  nova-network:
    driver: bridge
```

### Method 2: Cloud Platforms

#### AWS ECS/Fargate

```bash
# Push to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin your-account.dkr.ecr.us-east-1.amazonaws.com

docker push your-account.dkr.ecr.us-east-1.amazonaws.com/nova-api:0.1.0

# Create ECS task definition with environment variables
# Deploy via ECS console or CLI
```

#### Heroku

```bash
# Create app
heroku create nova-api

# Set environment variables
heroku config:set -a nova-api \
  DATABASE_URL=postgresql://... \
  JWT_SECRET=... \
  JWT_REFRESH_SECRET=... \
  NODE_ENV=production

# Deploy
git push heroku main
```

#### Google Cloud Run

```bash
# Build and push
gcloud builds submit --tag gcr.io/project-id/nova-api:0.1.0

# Deploy
gcloud run deploy nova-api \
  --image gcr.io/project-id/nova-api:0.1.0 \
  --platform managed \
  --region us-central1 \
  --set-env-vars DATABASE_URL=... \
  --set-env-vars JWT_SECRET=... \
  --set-env-vars JWT_REFRESH_SECRET=...
```

### Method 3: Traditional VPS

```bash
# SSH into server
ssh user@your-server.com

# Clone repository
git clone https://github.com/your-org/nova.git
cd nova/src/Backend

# Install Node.js 20+
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install dependencies
npm ci --omit=dev

# Set up environment
cp .env.example .env.production
# Edit .env.production with production secrets

# Build
npm run build

# Set up systemd service
sudo tee /etc/systemd/system/nova-api.service > /dev/null <<EOF
[Unit]
Description=Nova API Server
After=network.target

[Service]
Type=simple
User=nova
WorkingDirectory=/home/nova/nova/src/Backend
EnvironmentFile=/home/nova/nova/src/Backend/.env.production
ExecStart=/usr/bin/node dist/server.js
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Start service
sudo systemctl start nova-api
sudo systemctl enable nova-api
```

## Post-Deployment

### 1. Run Migrations

```bash
# If database is empty
npm run db:push

# Optional: Seed production with demo data
# npm run db:seed (only if needed)
```

### 2. Health Check

```bash
# Test health endpoint
curl https://api.nova-app.com/api/v1/health

# Should return:
# {
#   "status": "ok",
#   "version": "0.1.0",
#   "timestamp": "2026-04-13T...",
#   "database": "connected"
# }
```

### 3. Test Key Endpoints

```bash
# Sign up test user
curl -X POST https://api.nova-app.com/api/v1/auth/apple \
  -H "Content-Type: application/json" \
  -d '{"identityToken":"test","appleId":"test-user"}'

# Should return tokens and user object
```

### 4. Configure Monitoring

Set up monitoring for:
- API response times
- Error rates
- Database connection pool
- Memory usage
- CPU usage
- Disk space

Tools: DataDog, New Relic, CloudWatch, Prometheus, etc.

### 5. Configure Logging

```bash
# Send logs to centralized logging
# Examples: CloudWatch, Datadog, LogRocket, Splunk

# In production, ensure LOG_LEVEL=warn to reduce noise
```

### 6. Set Up Backups

```bash
# Database backups
# - Daily automated backups
# - 30-day retention minimum
# - Test restore procedures

# Example: PostgreSQL backup
pg_dump -Fc $DATABASE_URL > backup-$(date +%Y%m%d).dump
```

### 7. Configure CORS

Update CORS in `src/server.ts` to accept only your iOS app domain:

```typescript
await fastify.register(fastifyCors, {
  origin: ['https://your-app.domain'],  // iOS app domain
  credentials: true,
});
```

### 8. Set Up SSL/TLS

```bash
# Use Let's Encrypt with Certbot
sudo certbot certonly --standalone -d api.nova-app.com

# Or use managed certificates (AWS ACM, Google Cloud, etc.)

# Configure reverse proxy (nginx, Apache, or cloud load balancer)
```

## Load Testing

```bash
# Using Apache Bench
ab -n 1000 -c 10 https://api.nova-app.com/api/v1/health

# Using wrk
wrk -t4 -c100 -d30s https://api.nova-app.com/api/v1/health

# Expected: 1000+ requests/sec on modern hardware
```

## Scaling Strategies

### Horizontal Scaling

```bash
# Run multiple API instances behind load balancer
# - AWS ALB + ECS
# - Kubernetes with replicas
# - Docker Swarm

# Database read replicas
# - For read-heavy operations
# - Separate analytics queries
```

### Vertical Scaling

```bash
# Increase machine resources
# - More CPU cores
# - More RAM
# - Faster disk (SSD)
```

### Caching

```bash
# Add Redis for:
# - Session caching
# - API response caching
# - Rate limit buckets

# Implementation: Add @fastify/redis plugin
```

## Security Checklist

- [ ] HTTPS/TLS enabled
- [ ] All environment variables set correctly
- [ ] Database password is strong (20+ chars)
- [ ] JWT secrets are random (32+ chars)
- [ ] CORS configured for specific origins only
- [ ] Rate limiting enabled
- [ ] Security headers (Helmet) enabled
- [ ] Regular security updates
- [ ] Database backups verified
- [ ] Monitoring and alerting configured
- [ ] Log aggregation enabled
- [ ] Firewall rules restrict inbound traffic
- [ ] SSL certificate auto-renewal configured
- [ ] Incident response plan documented

## Rollback Procedure

```bash
# If deployment has issues, rollback to previous version
docker run -d \
  --name nova-api-previous \
  -p 3000:3000 \
  --env-file .env.production \
  your-registry.com/nova-api:0.1.0-prev

# Or if using systemd
sudo systemctl stop nova-api
cd /home/nova/nova/src/Backend
git checkout previous-commit-hash
npm ci --omit=dev
npm run build
sudo systemctl start nova-api
```

## Monitoring Dashboard

Create dashboards tracking:

- Request count (by endpoint)
- Error rate
- Response time (p50, p95, p99)
- Database connections
- Active users
- API errors by type
- CPU/Memory usage
- Disk I/O

## Incident Response

If issues occur:

1. Check logs: `docker logs nova-api` or `journalctl -u nova-api`
2. Check health: `curl /api/v1/health`
3. Check database connection
4. Check system resources
5. Rollback if necessary
6. Notify team
7. Post-mortem within 24 hours

## Maintenance

### Weekly

- Monitor error logs
- Check disk space
- Verify backups

### Monthly

- Review and update dependencies
- Rotate secrets if needed
- Security audit
- Performance analysis

### Quarterly

- Load testing
- Disaster recovery drill
- Security penetration test
- Update documentation

## Upgrade Path (v0.1.0 → v0.2.0)

```bash
# 1. Build new version
docker build -t nova-api:0.2.0 .

# 2. Test in staging environment
docker-compose -f docker-compose.staging.yml up

# 3. Run migrations
npm run db:migrate

# 4. Deploy with zero-downtime
# - Use blue-green deployment
# - Gradual traffic shifting (canary deployment)

# 5. Monitor for 24 hours
# - Watch error rates
# - Check performance metrics
# - Verify all endpoints work
```

## Support

For deployment issues:
- Check logs
- Verify environment variables
- Test database connection
- Ensure Node.js version is 20+
- Check disk space
- Review documentation

Contact: ops@nova-app.com

---

**Last Updated**: April 2026  
**Version**: 0.1.0  
**Status**: Production Ready
