# 🏗️ POC Data Engineering — INGESTION NIFI

> **Stack complète locale** : Apache NiFi · PostgreSQL · MinIO · Apache Iceberg · REST API · Google Drive (CSV) · Docker

---

## 🗺️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     SOURCES DE DONNÉES                          │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐   │
│  │ PostgreSQL  │  │  REST API   │  │  Google Drive (CSV)  │   │
│  │  source_db  │  │ :8000/docs  │  │  → /data/*.csv       │   │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬───────────┘   │
└─────────┼────────────────┼───────────────────  ┼───────────────┘
          │                │                     │
          └────────────────┴─────────────────────┘
                           │
                    ┌──────▼──────┐
                    │ Apache NiFi │  ← Ingestion & Routing
                    │   :8080     │
                    └──────┬──────┘

                          minio
```

---

## ⚡ Démarrage rapide (3 commandes)

```bash
# 1. Clone / dézippe le projet
cd poc-data-engineering

# 2. Lance tout
chmod +x start.sh && ./start.sh

# 3. Vérifie les données du warehouse
chmod +x scripts/query_warehouse.sh && ./scripts/query_warehouse.sh
```

**C'est tout.** Le script `start.sh` gère tout automatiquement.

---

## 🔧 Pré-requis

| Outil | Version min | Vérification |
|---|---|---|
| Docker | 24+ | `docker --version` |
| Docker Compose | 2.x | `docker compose version` |
| RAM disponible | 6 GB min | `free -h` (Linux) / Activity Monitor (Mac) |
| Ports libres | 5432, 5433, 8080, 8888, 9000, 9001, 8000, 4040 | |

---

## 📁 Structure du projet

```
poc-data-engineering/
├── docker-compose.yml              ← Orchestration de tous les services
│
├── postgres/
│   ├── init/01_init.sql            ← Données source (customers, products, orders)
│
├── api/
│   ├── main.py                     ← API Mock FastAPI (produits, events, stats)
│   └── Dockerfile
│
├── data/
│   └── sales_gdrive.csv            ← Simule les CSV Google Drive (30 ventes)
│
│
├── nifi/
│   ├── scripts/setup_nifi_flows.sh ← Config NiFi via API REST
│   └── templates/postgres_to_bronze.xml

```

---

## 🌐 Interfaces disponibles

| Service | URL | Identifiants |
|---|---|---|
| 🔧 **Apache NiFi** | http://localhost:8080 | admin / adminadminadmin |
| 🪣 **MinIO Console** | http://localhost:9001 | minioadmin / minioadmin123 |
| 🌐 **API Mock (Swagger)** | http://localhost:8000/docs | — |

---

## 🔄 Les 6 pipelines en détail

### Pipeline 1 — PostgreSQL Source → Bronze
```
postgres-source:5432/source_db
  tables: customers, products, orders, v_orders_full
  → MinIO: s3://bronze/postgres/{table}_{timestamp}.json
```
Extrait les données brutes en JSON et les dépose dans bronze tel quel.

### Pipeline 2 — API REST → Bronze
```
http://api-mock:8000
  endpoints: /products, /categories, /events, /stats
  → MinIO: s3://bronze/api/{endpoint}_{timestamp}.json
```
Appelle l'API mock et stocke les réponses JSON brutes.

### Pipeline 3 — CSV (Google Drive ou local ) → Bronze
```
/app/data/*.csv   (simule Google Drive)
  → MinIO: s3://bronze/gdrive/raw/{file}.csv
           s3://bronze/gdrive/json/{file}.json
```
Copie le CSV brut ET une version JSON dans bronze.



---

## 🔧 NiFi — Configuration manuelle des flows

NiFi est disponible sur http://localhost:8080. Voici comment créer les flows :

### Flow 1 : PostgreSQL → MinIO (Bronze)

1. **Drag** un `QueryDatabaseTable` sur le canvas
2. **Configure** le Controller Service `DBCPConnectionPool` :
   - Connection URL : `jdbc:postgresql://postgres-source:5432/source_db`
   - Driver Class : `org.postgresql.Driver`
   - Username : `admin` / Password : `admin123`
3. **QueryDatabaseTable** settings :
   - Table Name : `customers`
   - Max Rows Per Flow File : `1000`
4. **Connecte** à `ConvertAvroToJSON`
5. **Connecte** à `PutS3Object` :
   - Bucket : `bronze`
   - Object Key : `postgres/customers/${now():format('yyyyMMdd_HHmmss')}.json`
   - Endpoint Override URL : `http://minio:9000`
   - Access Key : `minioadmin`
   - Secret Key : `minioadmin123`
   - Path Style Access : `true`

### Flow 2 : API → MinIO (Bronze)

1. `GenerateFlowFile` (Run Schedule : `5 min`)
2. `InvokeHTTP` :
   - URL : `http://api-mock:8000/products?limit=100`
   - HTTP Method : `GET`
3. `PutS3Object` → bucket `bronze`, key `api/products/${now():format('yyyyMMdd')}.json`

### Flow 3 : CSV → MinIO (Bronze)

1. `GetFile` :
   - Input Directory : `/opt/nifi/data`
   - File Filter : `[^\.].*\.csv`
2. `PutS3Object` → bucket `bronze`, key `gdrive/${filename}`

---

