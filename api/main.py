"""
API Mock — simule une API externe de produits/catalogue
Accessible sur http://localhost:8000
"""
from fastapi import FastAPI, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import random
import datetime

app = FastAPI(
    title="Mock Products API",
    description="API externe simulée pour le POC Data Engineering",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Données simulées ──────────────────────────────────────────────

PRODUCTS = [
    {"id": 1,  "title": "iPhone 15 Pro",        "price": 1199.99, "rating": 4.8, "category": "smartphones",  "brand": "Apple",    "stock": 85},
    {"id": 2,  "title": "Samsung Galaxy S24",    "price": 999.00,  "rating": 4.6, "category": "smartphones",  "brand": "Samsung",  "stock": 120},
    {"id": 3,  "title": "MacBook Air M3",        "price": 1299.00, "rating": 4.9, "category": "laptops",      "brand": "Apple",    "stock": 45},
    {"id": 4,  "title": "Dell XPS 15",           "price": 1599.00, "rating": 4.5, "category": "laptops",      "brand": "Dell",     "stock": 30},
    {"id": 5,  "title": "Sony WH-1000XM5",       "price": 349.99,  "rating": 4.7, "category": "headphones",   "brand": "Sony",     "stock": 200},
    {"id": 6,  "title": "AirPods Pro 2",         "price": 249.00,  "rating": 4.6, "category": "headphones",   "brand": "Apple",    "stock": 300},
    {"id": 7,  "title": "iPad Pro 12.9",         "price": 1099.00, "rating": 4.8, "category": "tablets",      "brand": "Apple",    "stock": 60},
    {"id": 8,  "title": "Samsung Tab S9",        "price": 799.00,  "rating": 4.4, "category": "tablets",      "brand": "Samsung",  "stock": 90},
    {"id": 9,  "title": "LG 27 4K Monitor",    "price": 449.99,  "rating": 4.5, "category": "monitors",     "brand": "LG",       "stock": 40},
    {"id": 10, "title": "Logitech MX Master 3",  "price": 99.99,   "rating": 4.7, "category": "accessories",  "brand": "Logitech", "stock": 500},
    {"id": 11, "title": "Keychron K2 Keyboard",  "price": 89.00,   "rating": 4.6, "category": "accessories",  "brand": "Keychron", "stock": 250},
    {"id": 12, "title": "Anker USB-C Hub",        "price": 49.99,   "rating": 4.3, "category": "accessories",  "brand": "Anker",    "stock": 600},
]

EVENTS = []

def generate_event():
    """Génère un event aléatoire (simulation de stream)"""
    product = random.choice(PRODUCTS)
    return {
        "event_id": f"evt_{random.randint(100000, 999999)}",
        "event_type": random.choice(["view", "add_to_cart", "purchase", "wishlist"]),
        "product_id": product["id"],
        "product_title": product["title"],
        "user_id": f"user_{random.randint(1, 100)}",
        "session_id": f"sess_{random.randint(10000, 99999)}",
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "country": random.choice(["France", "Sénégal", "Brésil", "Allemagne", "Corée", "Portugal"]),
    }

# ── Endpoints ─────────────────────────────────────────────────────

@app.get("/", tags=["Health"])
def root():
    return {"status": "ok", "message": "Mock API opérationnelle", "endpoints": [
        "/products", "/products/{id}", "/products/category/{cat}",
        "/events", "/stats"
    ]}

@app.get("/health", tags=["Health"])
def health():
    return {"status": "healthy", "timestamp": datetime.datetime.utcnow().isoformat()}

@app.get("/products", tags=["Products"])
def get_products(
    limit: int = Query(default=50, le=100),
    category: Optional[str] = None,
    min_price: Optional[float] = None,
    max_price: Optional[float] = None,
):
    """Retourne la liste des produits avec filtres optionnels"""
    result = PRODUCTS.copy()
    if category:
        result = [p for p in result if p["category"] == category]
    if min_price is not None:
        result = [p for p in result if p["price"] >= min_price]
    if max_price is not None:
        result = [p for p in result if p["price"] <= max_price]
    return {"count": len(result[:limit]), "data": result[:limit]}

@app.get("/products/{product_id}", tags=["Products"])
def get_product(product_id: int):
    product = next((p for p in PRODUCTS if p["id"] == product_id), None)
    if not product:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Produit non trouvé")
    return product

@app.get("/products/category/{category}", tags=["Products"])
def get_by_category(category: str):
    result = [p for p in PRODUCTS if p["category"] == category]
    return {"category": category, "count": len(result), "data": result}

@app.get("/events", tags=["Events"])
def get_events(count: int = Query(default=20, le=100)):
    """Génère des événements utilisateur aléatoires (simulation)"""
    events = [generate_event() for _ in range(count)]
    return {"count": len(events), "data": events}

@app.get("/stats", tags=["Stats"])
def get_stats():
    """Statistiques globales simulées"""
    return {
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "total_products": len(PRODUCTS),
        "categories": list(set(p["category"] for p in PRODUCTS)),
        "avg_price": round(sum(p["price"] for p in PRODUCTS) / len(PRODUCTS), 2),
        "total_stock": sum(p["stock"] for p in PRODUCTS),
        "top_rated": sorted(PRODUCTS, key=lambda x: x["rating"], reverse=True)[:3],
    }

@app.get("/categories", tags=["Products"])
def get_categories():
    cats = {}
    for p in PRODUCTS:
        cat = p["category"]
        if cat not in cats:
            cats[cat] = {"name": cat, "count": 0, "avg_price": 0, "prices": []}
        cats[cat]["count"] += 1
        cats[cat]["prices"].append(p["price"])
    for cat in cats:
        cats[cat]["avg_price"] = round(sum(cats[cat]["prices"]) / len(cats[cat]["prices"]), 2)
        del cats[cat]["prices"]
    return {"categories": list(cats.values())}
