# 🍴 Tamu City Database

The **Tamu City Database** is a relational schema built in **MySQL** to support a food ordering and restaurant management system.  
It powers the backend for the Tamu City website/app, handling customers, menu items, orders, inventory, and payments.

---

## 📋 Overview

The database was designed with:
- **Relational design principles** (tables, keys, constraints).
- **Data integrity** via **PRIMARY KEY**, **FOREIGN KEY**, **NOT NULL**, and **UNIQUE** constraints.
- **Business rules enforcement** using triggers, stored functions, and procedures.
- **Views** for simplified reporting (e.g., order summaries, top-selling items).
- **Transactions** for reliable order processing.

---

## 🏗️ Database Schema

The schema contains **7 main tables** and supporting logic:

### 1. `customers`
Stores customer details.
### 2.  `categories`
Groups menu items into categories.
### 3.  `menu_items`
Represents all dishes/drinks/desserts.
### 4.  `orders`
Tracks each order placed by a customer.
### 5. `order_items `
Links menu items to orders (many-to-many relationship).
### 6.  `payments`
Handles payments for orders.
### 7. `employees (optional)`
For staff management.
