-- PostgreSQL 15+ practice schema. Run once in a dedicated training database.
-- Intentional failure if schema already exists: existing work is not overwritten.
BEGIN;
CREATE SCHEMA interview_lab;
SET LOCAL search_path = interview_lab, public;

CREATE TABLE tenants (id integer PRIMARY KEY, name text NOT NULL UNIQUE);
CREATE TABLE customers (
    id integer PRIMARY KEY,
    tenant_id integer NOT NULL REFERENCES tenants(id),
    name text NOT NULL,
    email text NOT NULL,
    city text,
    created_at timestamptz NOT NULL,
    UNIQUE (tenant_id, email),
    UNIQUE (tenant_id, id)
);
CREATE TABLE products (
    id integer PRIMARY KEY,
    name text NOT NULL,
    category text NOT NULL,
    price numeric(12,2) NOT NULL CHECK (price >= 0)
);
CREATE TABLE orders (
    id integer PRIMARY KEY,
    tenant_id integer NOT NULL REFERENCES tenants(id),
    customer_id integer NOT NULL,
    status text NOT NULL CHECK (status IN ('paid','pending','cancelled','refunded')),
    created_at timestamptz NOT NULL,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    FOREIGN KEY (tenant_id, customer_id) REFERENCES customers(tenant_id, id)
);
CREATE TABLE order_items (
    order_id integer NOT NULL REFERENCES orders(id),
    product_id integer NOT NULL REFERENCES products(id),
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, product_id)
);
CREATE TABLE payments (
    id integer PRIMARY KEY,
    order_id integer NOT NULL REFERENCES orders(id),
    provider_ref text NOT NULL UNIQUE,
    status text NOT NULL CHECK (status IN ('succeeded','failed','refunded')),
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    created_at timestamptz NOT NULL
);
CREATE TABLE departments (id integer PRIMARY KEY, name text NOT NULL UNIQUE);
CREATE TABLE employees (
    id integer PRIMARY KEY,
    name text NOT NULL,
    department_id integer NOT NULL REFERENCES departments(id),
    manager_id integer REFERENCES employees(id),
    salary numeric(12,2) NOT NULL CHECK (salary >= 0),
    hired_at date NOT NULL
);
CREATE TABLE login_events (
    id integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers(id),
    logged_at timestamptz NOT NULL
);
CREATE TABLE inventory (
    product_id integer PRIMARY KEY REFERENCES products(id),
    stock integer NOT NULL CHECK (stock >= 0),
    version integer NOT NULL DEFAULT 1 CHECK (version > 0)
);
CREATE TABLE webhook_events (
    event_id text PRIMARY KEY,
    payload jsonb NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now()
);
CREATE VIEW order_totals AS
SELECT order_id, SUM(quantity * unit_price)::numeric(12,2) AS total
FROM order_items GROUP BY order_id;
COMMIT;
