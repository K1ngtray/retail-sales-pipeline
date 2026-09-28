-- Retail Sales Pipeline: database schema
-- Requires MySQL 8.0+
-- Run this once in MySQL Workbench before running 05_load.ipynb

CREATE DATABASE IF NOT EXISTS retail_db;
USE retail_db;

-- One row per unique registered customer.
-- Guest checkouts have no customer_id, so they do not appear here.
CREATE TABLE IF NOT EXISTS dim_customer (
    customer_id INT PRIMARY KEY,
    country VARCHAR(50)
);

-- One row per unique product.
-- stock_code is uppercased and whitespace-stripped before loading,
-- because MySQL treats '72349B' and '72349b' as the same key.
CREATE TABLE IF NOT EXISTS dim_product (
    stock_code VARCHAR(20) PRIMARY KEY,
    description VARCHAR(255)
);

-- One row per transaction line item.
-- customer_id is NULL for guest checkouts.
-- country is stored here directly so guest checkouts keep their country.
CREATE TABLE IF NOT EXISTS fact_sales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    invoice_no VARCHAR(20),
    stock_code VARCHAR(20),
    customer_id INT,
    invoice_date DATETIME,
    quantity INT,
    unit_price DECIMAL(10,2),
    line_total DECIMAL(10,2),
    is_cancellation BOOLEAN,
    country VARCHAR(50),
    FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
    FOREIGN KEY (stock_code) REFERENCES dim_product(stock_code)
);
