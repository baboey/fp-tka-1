#!/bin/bash

# Prepare the user credentials for MongoDB
q_MONGO_USER=$(jq --arg v "$MONGO_USER" -n '$v')
q_MONGO_PASSWORD=$(jq --arg v "$MONGO_PASSWORD" -n '$v')

echo "=== Creating Database User ==="
mongosh -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" admin <<EOF
    use $MONGO_INITDB_DATABASE;
    db.createUser({
        user: $q_MONGO_USER,
        pwd: $q_MONGO_PASSWORD,
        roles: ["readWrite"],
    });
EOF

echo "=== Restoring Database Seed Dump ==="
mongorestore -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --drop /dump/

echo "=== Creating Database Indexes ==="
mongosh -u "$MONGO_INITDB_ROOT_USERNAME" -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin <<EOF
    use $MONGO_INITDB_DATABASE;
    
    // Index untuk users
    db.users.createIndex({ "email": 1 }, { unique: true });
    db.users.createIndex({ "role": 1, "is_active": 1 });
    
    // Index untuk products
    db.products.createIndex({ "is_active": 1, "created_at": -1 });
    db.products.createIndex({ "is_active": 1, "category": 1, "created_at": -1 });
    db.products.createIndex({ "is_active": 1, "price": 1 });
    db.products.createIndex({ "is_active": 1, "rating": -1 });
    
    // Index untuk orders
    db.orders.createIndex({ "order_id": 1 }, { unique: true });
    db.orders.createIndex({ "created_at": -1 });
    db.orders.createIndex({ "user_id": 1, "created_at": -1 });
    db.orders.createIndex({ "status": 1, "created_at": -1 });
    
    // Index untuk audit_logs
    db.audit_logs.createIndex({ "created_at": -1 });
EOF

echo "=== Database Seeding Completed ==="
