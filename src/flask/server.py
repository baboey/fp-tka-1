#!/usr/bin/env python
import os
import uuid

from datetime import datetime
from flask import Flask, request, jsonify
from pymongo import MongoClient

app = Flask(__name__)


client = MongoClient("mongodb://root:root@mongo:27017") 
db = client["database"]

@app.route('/')
def todo():
    try:
        client.admin.command('ismaster')
    except:
        return { "message":"server not available", "success":False}, 501
    return { "message":"MongoDB is connected to backend","success":True}, 200

@app.route('/order', methods=['POST'])
def order():
    try:
        data = request.get_json(silent=True)
        data["order_id"]=str(uuid.uuid4())
        data["status"]="pending"
        data["total"]=data["price"]*data["quantity"]
        data["created_at"]=str(datetime.now())
        db.orders.insert_one(data)
        return  str(data), 201
    except:
        return { "message":"server not available", "success":False}, 501

@app.route('/order/<order_id>', methods=['GET','PUT'])
def get_order(order_id):
    if request.method == 'GET':
        match = db.orders.find_one({"order_id":order_id})
        if match:
            return str(match)
        else:
            return { "message":"Order not found", "sucess":False }, 404
    if request.method == 'PUT':
        update_data = request.get_json()
        result = db.orders.update_one({"order_id":order_id}, {"$set": update_data})
        return { "order_id":order_id, "status": update_data["status"]}

@app.route('/orders', methods=['GET'])
def get_orders():
    match = db.orders.find().sort({ 'price': -1 })
    return str(list(match)), 200

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=os.environ.get("FLASK_SERVER_PORT", 9090), debug=True)
