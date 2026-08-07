FROM python:3.12-slim

WORKDIR /app

# Dependencies first so a source edit does not reinstall asyncpg.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Source. .dockerignore keeps scripts/, tests/, frontend/ and the .env
# files out — see the notes there.
COPY . .

# The app answers under /api in ECS: CloudFront matches /api/*, the ALB
# rule that picks this service out of the two behind the load balancer
# matches /api/*, so the app has to serve /api/* too. Empty locally.
ENV API_PREFIX=/api \
    PYTHONUNBUFFERED=1

EXPOSE 9010

# Note the path: the health endpoint moves with API_PREFIX, so this has
# to move with it. urlopen raises on any non-2xx, which is the exit code
# Docker wants.
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=40s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:9010/api/health')"

# Two workers on 512 CPU units (half a vCPU). Each opens its own pair of
# asyncpg pools, so this is 2× the connection count against RDS — fine
# at this size, worth revisiting before scaling the service out.
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "9010", "--workers", "2"]
