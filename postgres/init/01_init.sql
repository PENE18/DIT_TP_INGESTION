-- ================================================================
-- SOURCE DATABASE: données opérationnelles
-- ================================================================

-- Table customers
CREATE TABLE IF NOT EXISTS customers (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  email       VARCHAR(150) UNIQUE NOT NULL,
  country     VARCHAR(50),
  city        VARCHAR(80),
  age         INT,
  segment     VARCHAR(30),  -- 'premium', 'standard', 'trial'
  created_at  TIMESTAMP DEFAULT NOW(),
  updated_at  TIMESTAMP DEFAULT NOW()
);

-- Table products
CREATE TABLE IF NOT EXISTS products (
  id          SERIAL PRIMARY KEY,
  sku         VARCHAR(50) UNIQUE NOT NULL,
  name        VARCHAR(150) NOT NULL,
  category    VARCHAR(60),
  price       NUMERIC(10,2),
  stock       INT DEFAULT 0,
  created_at  TIMESTAMP DEFAULT NOW()
);

-- Table orders
CREATE TABLE IF NOT EXISTS orders (
  id           SERIAL PRIMARY KEY,
  customer_id  INT REFERENCES customers(id),
  product_id   INT REFERENCES products(id),
  quantity     INT DEFAULT 1,
  unit_price   NUMERIC(10,2),
  total_amount NUMERIC(10,2),
  status       VARCHAR(20),  -- 'pending','processing','completed','cancelled'
  order_date   TIMESTAMP DEFAULT NOW()
);

-- ================================================================
-- DONNÉES DE TEST
-- ================================================================

INSERT INTO customers (name, email, country, city, age, segment) VALUES
  ('Alice Dupont',      'alice@example.com',    'France',   'Paris',    34, 'premium'),
  ('Bob Traoré',        'bob@example.com',      'Sénégal',  'Dakar',    28, 'standard'),
  ('Clara Silva',       'clara@example.com',    'Brésil',   'São Paulo',41, 'premium'),
  ('David Kim',         'david@example.com',    'Corée',    'Séoul',    25, 'trial'),
  ('Emilie Martin',     'emilie@example.com',   'France',   'Lyon',     37, 'standard'),
  ('Fatou Diallo',      'fatou@example.com',    'Sénégal',  'Dakar',    30, 'premium'),
  ('Georges Leroy',     'georges@example.com',  'France',   'Bordeaux', 52, 'standard'),
  ('Hana Müller',       'hana@example.com',     'Allemagne','Berlin',   29, 'trial'),
  ('Ibrahim Ba',        'ibrahim@example.com',  'Sénégal',  'Thiès',    45, 'standard'),
  ('Julia Santos',      'julia@example.com',    'Brésil',   'Rio',      33, 'premium'),
  ('Khalil Messaoud',   'khalil@example.com',   'Tunisie',  'Tunis',    38, 'standard'),
  ('Laura Ferreira',    'laura@example.com',    'Portugal', 'Lisbonne', 27, 'trial');

INSERT INTO products (sku, name, category, price, stock) VALUES
  ('LAPTOP-001', 'Laptop Pro 15',      'Électronique', 1299.99, 50),
  ('PHONE-001',  'Smartphone X12',     'Électronique',  799.00, 120),
  ('TABLET-001', 'Tablette Ultra',     'Électronique',  499.50, 75),
  ('HEADP-001',  'Casque Bluetooth',   'Accessoires',   149.90, 200),
  ('KEYB-001',   'Clavier Mécanique',  'Accessoires',    89.00, 300),
  ('MONIT-001',  'Écran 4K 27"',       'Électronique',  599.00, 30),
  ('MOUSE-001',  'Souris Ergonomique', 'Accessoires',    59.99, 250),
  ('DESK-001',   'Webcam HD',          'Accessoires',    79.00, 180);

INSERT INTO orders (customer_id, product_id, quantity, unit_price, total_amount, status, order_date) VALUES
  (1,  1, 1, 1299.99, 1299.99, 'completed',  NOW() - INTERVAL '30 days'),
  (1,  4, 2,  149.90,  299.80, 'completed',  NOW() - INTERVAL '25 days'),
  (2,  2, 1,  799.00,  799.00, 'completed',  NOW() - INTERVAL '20 days'),
  (3,  3, 1,  499.50,  499.50, 'processing', NOW() - INTERVAL '15 days'),
  (4,  5, 3,   89.00,  267.00, 'pending',    NOW() - INTERVAL '10 days'),
  (5,  6, 1,  599.00,  599.00, 'completed',  NOW() - INTERVAL '8 days'),
  (6,  2, 2,  799.00, 1598.00, 'completed',  NOW() - INTERVAL '6 days'),
  (7,  7, 1,   59.99,   59.99, 'cancelled',  NOW() - INTERVAL '5 days'),
  (8,  1, 1, 1299.99, 1299.99, 'processing', NOW() - INTERVAL '4 days'),
  (9,  4, 1,  149.90,  149.90, 'completed',  NOW() - INTERVAL '3 days'),
  (10, 8, 2,   79.00,  158.00, 'completed',  NOW() - INTERVAL '2 days'),
  (11, 3, 1,  499.50,  499.50, 'pending',    NOW() - INTERVAL '1 day'),
  (12, 5, 2,   89.00,  178.00, 'completed',  NOW()),
  (2,  6, 1,  599.00,  599.00, 'completed',  NOW() - INTERVAL '12 days'),
  (3,  1, 1, 1299.99, 1299.99, 'completed',  NOW() - INTERVAL '18 days');

-- Vue pratique pour NiFi
CREATE OR REPLACE VIEW v_orders_full AS
SELECT
  o.id          AS order_id,
  c.name        AS customer_name,
  c.email       AS customer_email,
  c.country,
  c.segment,
  p.sku,
  p.name        AS product_name,
  p.category,
  o.quantity,
  o.unit_price,
  o.total_amount,
  o.status,
  o.order_date
FROM orders o
JOIN customers c ON o.customer_id = c.id
JOIN products  p ON o.product_id  = p.id;

DO $$
BEGIN
    RAISE NOTICE 'Source DB initialisée: % customers, % products, % orders',
        (SELECT COUNT(*) FROM customers),
        (SELECT COUNT(*) FROM products),
        (SELECT COUNT(*) FROM orders);
END $$;
