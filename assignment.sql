-- tamu_city_schema.sql
-- Restaurant Database for "Tamu City"
-- MySQL script: creates schema, tables, constraints, sample data, views, functions, procedures, triggers.
-- Run: mysql -u root -p < tamu_city_schema.sql
-- NOTE: Adjust SQL mode / user privileges as needed.

-- ===================================================
-- 0. Cleanup if re-running
-- ===================================================
DROP DATABASE IF EXISTS tamu_city;
CREATE DATABASE tamu_city CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tamu_city;

-- ===================================================
-- 1. Tables
-- ===================================================

-- 1.1 Customers
CREATE TABLE customers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  phone VARCHAR(30) NOT NULL,
  email VARCHAR(150),
  address VARCHAR(300),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_customers_phone (phone)
);

-- 1.2 Menu categories
CREATE TABLE categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(255)
);

-- 1.3 Menu items (products)
CREATE TABLE menu_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  category_id INT NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  price DECIMAL(10,2) NOT NULL CHECK (price >= 0),
  stock INT NOT NULL DEFAULT 0, -- quantity in inventory
  is_available TINYINT(1) NOT NULL DEFAULT 1, -- 1 available, 0 not
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  UNIQUE KEY uq_menu_name (name)
);

-- 1.4 Orders
CREATE TABLE orders (
  id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NULL,
  order_status ENUM('pending','confirmed','preparing','ready','delivered','cancelled') NOT NULL DEFAULT 'pending',
  order_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  delivery_address VARCHAR(300),
  delivery_fee DECIMAL(8,2) DEFAULT 50.00,
  notes VARCHAR(500),
  total_amount DECIMAL(10,2) DEFAULT 0.00,
  FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- 1.5 Order items (junction table) - many-to-many between orders and menu_items
CREATE TABLE order_items (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  menu_item_id INT NOT NULL,
  unit_price DECIMAL(10,2) NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  line_total DECIMAL(10,2) NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY (menu_item_id) REFERENCES menu_items(id) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_order_items_orderid (order_id),
  INDEX idx_order_items_menuitemid (menu_item_id)
);

-- 1.6 Payments
CREATE TABLE payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  order_id INT NOT NULL,
  paid_amount DECIMAL(10,2) NOT NULL,
  paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  method ENUM('cash','mpesa','card','other') DEFAULT 'cash',
  note VARCHAR(255),
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- 1.7 Employees (optional for future features)
CREATE TABLE employees (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(150) NOT NULL,
  role VARCHAR(80),
  phone VARCHAR(30),
  hired_date DATE,
  UNIQUE KEY uq_employee_phone (phone)
);

-- ===================================================
-- 2. Sample data
-- ===================================================

-- categories
INSERT INTO categories (name, description) VALUES
('Starters', 'Appetizers and small plates'),
('Mains', 'Main dishes'),
('Drinks', 'Beverages'),
('Desserts', 'Sweet treats');

-- menu items (some Kenyan examples)
INSERT INTO menu_items (category_id, name, description, price, stock, is_available) VALUES
(1, 'Samosa (Beef)', 'Crispy pastry filled with spiced beef', 100.00, 50, 1),
(1, 'Samosa (Veg)', 'Crispy pastry with spiced vegetables', 90.00, 40, 1),
(2, 'Ugali & Sukuma Wiki', 'Maize porridge with sautéed collard greens', 250.00, 100, 1),
(2, 'Nyama Choma (Goat)', 'Charcoal grilled goat served with kachumbari', 700.00, 30, 1),
(2, 'Pilau', 'Spiced rice cooked with beef and aromatic spices', 500.00, 40, 1),
(2, 'Tilapia Fry', 'Whole fried tilapia with sides', 650.00, 20, 1),
(3, 'Fresh Sugarcane Juice', 'Freshly squeezed with lime', 150.00, 60, 1),
(4, 'Mandazi', 'Sweet fried dough', 50.00, 200, 1);

-- customers
INSERT INTO customers (full_name, phone, email, address) VALUES
('Kim Ndegwa', '+254700123456', 'kim@example.com', 'Nairobi, Kileleshwa'),
('Nancy Obwina', '+254700222333', 'nancy@example.com', 'Nairobi, Westlands');

-- example order + items
INSERT INTO orders (customer_id, order_status, delivery_address, delivery_fee, notes)
VALUES (1, 'pending', 'Kileleshwa Road, Nairobi', 50.00, 'Leave at gate if not home');

SET @last_order_id = LAST_INSERT_ID();

INSERT INTO order_items (order_id, menu_item_id, unit_price, quantity, line_total)
VALUES
(@last_order_id, (SELECT id FROM menu_items WHERE name='Ugali & Sukuma Wiki'), 250.00, 1, 250.00),
(@last_order_id, (SELECT id FROM menu_items WHERE name='Mandazi'), 50.00, 3, 150.00);

-- update order total
UPDATE orders
SET total_amount = (SELECT COALESCE(SUM(line_total),0) FROM order_items WHERE order_id = orders.id) + delivery_fee
WHERE id = @last_order_id;

-- sample payment
INSERT INTO payments (order_id, paid_amount, method, note)
VALUES (@last_order_id, 450.00, 'mpesa', 'Partial payment');

-- ===================================================
-- 3. Views and Reporting
-- ===================================================

-- 3.1 Order summary view (one row per order)
CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
  o.id AS order_id,
  o.order_time,
  o.order_status,
  COALESCE(c.full_name, 'Guest') AS customer_name,
  o.delivery_address,
  o.total_amount,
  COALESCE(p.paid_total, 0) AS amount_paid,
  (o.total_amount - COALESCE(p.paid_total, 0)) AS balance_due
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id
LEFT JOIN (
  SELECT order_id, SUM(paid_amount) AS paid_total
  FROM payments
  GROUP BY order_id
) p ON p.order_id = o.id;

-- 3.2 Top selling menu items (by quantity)
CREATE OR REPLACE VIEW vw_top_items AS
SELECT mi.id AS menu_item_id, mi.name, SUM(oi.quantity) AS total_sold
FROM order_items oi
JOIN menu_items mi ON oi.menu_item_id = mi.id
GROUP BY mi.id, mi.name
ORDER BY total_sold DESC;

-- ===================================================
-- 4. Stored Functions & Procedures
-- ===================================================

-- 4.1 Function: calculate_order_total(order_id)
DROP FUNCTION IF EXISTS calculate_order_total;
DELIMITER $$
CREATE FUNCTION calculate_order_total(ord_id INT) RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
  DECLARE tot DECIMAL(10,2);
  SELECT COALESCE(SUM(line_total),0) INTO tot FROM order_items WHERE order_id = ord_id;
  SELECT COALESCE(delivery_fee,0) INTO @df FROM orders WHERE id = ord_id;
  RETURN COALESCE(tot,0) + COALESCE(@df,0);
END $$
DELIMITER ;

-- 4.2 Procedure: place_order (transactional example)
-- Accepts customer_id (nullable), delivery_address, array-like of items (menu_item_id & quantity)
-- Note: MySQL stored procs don't accept arrays easily; here we demonstrate a simple use-case by inserting one item.
-- In real use, you would call this proc multiple times or implement logic that reads from a temp table.

DROP PROCEDURE IF EXISTS demo_place_order;
DELIMITER $$
CREATE PROCEDURE demo_place_order(
  IN p_customer_id INT,
  IN p_delivery_address VARCHAR(300),
  IN p_menu_item_id INT,
  IN p_quantity INT
)
BEGIN
  DECLARE v_order_id INT;
  DECLARE v_unit_price DECIMAL(10,2);

  -- start transaction
  START TRANSACTION;
  INSERT INTO orders (customer_id, delivery_address, delivery_fee, order_status)
  VALUES (p_customer_id, p_delivery_address, 50.00, 'confirmed');

  SET v_order_id = LAST_INSERT_ID();

  SELECT price INTO v_unit_price FROM menu_items WHERE id = p_menu_item_id FOR UPDATE;

  INSERT INTO order_items (order_id, menu_item_id, unit_price, quantity, line_total)
  VALUES (v_order_id, p_menu_item_id, v_unit_price, p_quantity, v_unit_price * p_quantity);

  -- update order total
  UPDATE orders
  SET total_amount = (SELECT COALESCE(SUM(line_total),0) FROM order_items WHERE order_id = v_order_id) + delivery_fee
  WHERE id = v_order_id;

  -- reduce stock (simple)
  UPDATE menu_items SET stock = stock - p_quantity WHERE id = p_menu_item_id;

  COMMIT;
END $$
DELIMITER ;

-- ===================================================
-- 5. Triggers
-- ===================================================

-- 5.1 Trigger: ensure line_total correct on insert
DROP TRIGGER IF EXISTS trg_order_items_before_insert;
DELIMITER $$
CREATE TRIGGER trg_order_items_before_insert
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
  -- set line_total = unit_price * quantity
  SET NEW.line_total = NEW.unit_price * NEW.quantity;
END$$
DELIMITER ;

-- 5.2 Trigger: prevent negative stock on insert to order_items (will rollback if insufficient)
DROP TRIGGER IF EXISTS trg_order_items_after_insert;
DELIMITER $$
CREATE TRIGGER trg_order_items_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
  DECLARE current_stock INT;
  SELECT stock INTO current_stock FROM menu_items WHERE id = NEW.menu_item_id;
  IF current_stock < NEW.quantity THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock for menu item';
  ELSE
    UPDATE menu_items SET stock = stock - NEW.quantity WHERE id = NEW.menu_item_id;
  END IF;
END$$
DELIMITER ;

-- 5.3 Trigger: restore stock on order_items delete (e.g., when order item removed)
DROP TRIGGER IF EXISTS trg_order_items_after_delete;
DELIMITER $$
CREATE TRIGGER trg_order_items_after_delete
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
  UPDATE menu_items SET stock = stock + OLD.quantity WHERE id = OLD.menu_item_id;
END$$
DELIMITER ;

-- ===================================================
-- 6. Example Queries & Usage
-- ===================================================

-- 6.1 List current menu with stock
SELECT id, name, price, stock, is_available FROM menu_items ORDER BY category_id, name;

-- 6.2 Get order summary view
SELECT * FROM vw_order_summary LIMIT 10;

-- 6.3 Get top selling items
SELECT * FROM vw_top_items LIMIT 10;

-- 6.4 Use the demo procedure to place an order (example)
-- CALL demo_place_order(1, 'Kileleshwa Road, Nairobi', (SELECT id FROM menu_items WHERE name='Pilau'), 2);

-- 6.5 Use calculate_order_total
-- SELECT calculate_order_total(1);

-- ===================================================
-- 7. Additional sample: create an order using SQL (multi-row)
-- ===================================================
-- Demonstration of a multi-item order using explicit SQL (recommended in app code)
INSERT INTO orders (customer_id, order_status, delivery_address, delivery_fee, notes)
VALUES (2, 'pending', 'Westlands, Nairobi', 50.00, 'Call on arrival');

SET @oid = LAST_INSERT_ID();

INSERT INTO order_items (order_id, menu_item_id, unit_price, quantity)
VALUES (@oid, (SELECT id FROM menu_items WHERE name='Pilau'), 500.00, 1),
       (@oid, (SELECT id FROM menu_items WHERE name='Fresh Sugarcane Juice'), 150.00, 2);

-- update total
UPDATE orders
SET total_amount = (SELECT COALESCE(SUM(line_total),0) FROM order_items WHERE order_id = orders.id) + delivery_fee
WHERE id = @oid;

-- ===================================================
-- 8. Indexes & performance hints
-- ===================================================
CREATE INDEX idx_menu_category ON menu_items(category_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_payments_order ON payments(order_id);

-- ===================================================
-- 9. Final notes & cleanup hints
-- ===================================================
-- Use the provided views for reporting. The triggers will protect stock integrity for simple operations.
-- For production-grade systems, consider:
--   * More sophisticated inventory movements table (stock_movement)
--   * Soft deletes (is_active flags) instead of hard deletes
--   * Referential cascade rules carefully chosen per business rules
--   * Input validation at application layer
