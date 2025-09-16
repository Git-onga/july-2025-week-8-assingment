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
```sql
id INT PK
full_name VARCHAR(150) NOT NULL
phone VARCHAR(30) UNIQUE NOT NULL
email VARCHAR(150)
address VARCHAR(300)
created_at TIMESTAMP
