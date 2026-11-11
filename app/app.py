import os
from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def home():
    return jsonify(message="Hello from the DevOps assessment", version=os.getenv("APP_VERSION", "dev"))


@app.get("/health")
def health():
    return jsonify(status="ok"), 200
