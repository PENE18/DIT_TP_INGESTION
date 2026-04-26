#!/bin/bash
# ================================================================
# setup_nifi_flows.sh
# Configure les flows NiFi via l'API REST
# Usage: ./nifi/scripts/setup_nifi_flows.sh
# ================================================================

NIFI_URL="http://localhost:8080"
NIFI_USER="admin"
NIFI_PASS="adminadminadmin"

echo "═══════════════════════════════════════════════════"
echo "  Configuration NiFi — POC Data Engineering"
echo "═══════════════════════════════════════════════════"

# Attente NiFi
echo "⏳ Attente démarrage NiFi..."
until curl -sf "$NIFI_URL/nifi/" > /dev/null; do
    echo "  NiFi pas encore prêt, attente 15s..."
    sleep 15
done
echo "✅ NiFi est prêt!"
sleep 5

# Récupère le token JWT
echo ""
echo "🔐 Authentification NiFi..."
TOKEN=$(curl -sf -X POST \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=${NIFI_USER}&password=${NIFI_PASS}" \
    "${NIFI_URL}/nifi-api/access/token" 2>/dev/null || echo "")

if [ -z "$TOKEN" ]; then
    echo "⚠️  Pas de token (NiFi en mode HTTP non-auth) — on continue sans auth"
    AUTH_HEADER=""
else
    echo "✅ Token obtenu"
    AUTH_HEADER="-H 'Authorization: Bearer $TOKEN'"
fi

# Récupère le Root Process Group ID
ROOT_PG_ID=$(curl -sf \
    -H "Content-Type: application/json" \
    "${NIFI_URL}/nifi-api/flow/process-groups/root" | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['processGroupFlow']['id'])" 2>/dev/null)

echo "📋 Root Process Group: $ROOT_PG_ID"

# ── Crée un Process Group pour le POC ────────────────────────────
echo ""
echo "📁 Création du Process Group 'POC Medallion'..."
PG_RESP=$(curl -sf -X POST \
    -H "Content-Type: application/json" \
    -d "{
        \"revision\": {\"version\": 0},
        \"component\": {
            \"name\": \"POC Medallion Architecture\",
            \"position\": {\"x\": 100, \"y\": 100}
        }
    }" \
    "${NIFI_URL}/nifi-api/process-groups/${ROOT_PG_ID}/process-groups")

POC_PG_ID=$(echo "$PG_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
echo "✅ Process Group créé: $POC_PG_ID"

echo ""
echo "═══════════════════════════════════════════════════"
echo "  NiFi est configuré!"
echo ""
echo "  👉 Ouvre http://localhost:8080"
echo "     Login: admin / adminadminadmin"
echo ""
echo "  Pour créer les flows manuellement:"
echo ""
echo "  FLOW 1: QueryDatabaseTable → MinIO (PostgreSQL)"
echo "  ─────────────────────────────────────────────────"
echo "  Processors:"
echo "  1. QueryDatabaseTable"
echo "     - Database Connection Pooling Service:"
echo "       DBCPConnectionPool"
echo "       → DB URL: jdbc:postgresql://postgres-source:5432/source_db"
echo "       → Driver: org.postgresql.Driver"
echo "       → User: admin / Password: admin123"
echo "     - DB Table Name: customers (puis products, orders)"
echo "     - Max Rows Per Flow File: 1000"
echo ""
echo "  2. ConvertAvroToJSON (JSON Writer)"
echo ""
echo "  3. PutS3Object"
echo "     - Bucket: bronze"
echo "     - Object Key: postgres/\${table.name}/\${now():format('yyyyMMdd_HHmmss')}.json"
echo "     - Endpoint Override: http://minio:9000"
echo "     - Access Key: minioadmin"
echo "     - Secret Key: minioadmin123"
echo "     - Path Style Access: true"
echo "     - Region: us-east-1"
echo ""
echo "  FLOW 2: InvokeHTTP → MinIO (API REST)"
echo "  ─────────────────────────────────────────────────"
echo "  1. GenerateFlowFile (trigger toutes les 5 min)"
echo "  2. InvokeHTTP"
echo "     - HTTP Method: GET"
echo "     - Remote URL: http://api-mock:8000/products?limit=100"
echo "  3. PutS3Object"
echo "     - Bucket: bronze"
echo "     - Object Key: api/products/\${now():format('yyyyMMdd_HHmmss')}.json"
echo ""
echo "  FLOW 3: GetFile → MinIO (CSV Google Drive)"
echo "  ─────────────────────────────────────────────────"
echo "  1. GetFile"
echo "     - Input Directory: /opt/nifi/data"
echo "     - File Filter: .*\.csv"
echo "  2. PutS3Object"
echo "     - Bucket: bronze"  
echo "     - Object Key: gdrive/\${filename}"
echo "═══════════════════════════════════════════════════"
