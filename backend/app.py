import os
import sys

# Ensure backend root is in sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from flask import Flask, jsonify, send_from_directory, redirect
from flask_cors import CORS
from sqlalchemy import text

from backend.config import Config
from backend.extensions import db, socketio
from backend.routes import (
    trains_bp,
    stations_bp,
    crowd_bp,
    tracking_bp,
    simulation_bp,
    auth_bp,
)

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    # Enable CORS for Flutter mobile app, admin dashboard, and web browsers
    CORS(app, resources={r"/api/*": {"origins": "*"}})

    # Initialize extensions
    db.init_app(app)
    socketio.init_app(app, cors_allowed_origins="*")

    # Register blueprints
    app.register_blueprint(trains_bp)
    app.register_blueprint(stations_bp)
    app.register_blueprint(crowd_bp)
    app.register_blueprint(tracking_bp)
    app.register_blueprint(simulation_bp)
    app.register_blueprint(auth_bp)

    # Web Dashboard Static Hosting
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    admin_dir = os.path.join(base_dir, "admin_dashboard")
    sim_dir = os.path.join(base_dir, "simulation")

    @app.get("/")
    def index():
        return redirect("/admin/")

    @app.get("/admin")
    def admin_redirect():
        return redirect("/admin/")

    @app.get("/admin/")
    def admin_root():
        return send_from_directory(admin_dir, "index.html")

    @app.get("/admin/<path:filename>")
    def admin_static(filename):
        return send_from_directory(admin_dir, filename)

    @app.get("/simulation")
    def simulation_redirect():
        return redirect("/simulation/")

    @app.get("/simulation/")
    def simulation_root():
        return send_from_directory(sim_dir, "index.html")

    @app.get("/simulation/<path:filename>")
    def simulation_static(filename):
        return send_from_directory(sim_dir, filename)

    # Fallback if browser requests assets from root path
    @app.get("/style.css")
    def root_style():
        return send_from_directory(admin_dir, "style.css")

    @app.get("/script.js")
    def root_script():
        return send_from_directory(admin_dir, "script.js")

    @app.get("/api/health")
    def health():
        try:
            db.session.execute(text("SELECT 1"))
            return jsonify({
                "status": "ok",
                "database": "connected",
                "socketio": "enabled",
                "version": "2.0.0-gps-crowd-mvp"
            })
        except Exception as exc:
            return jsonify({
                "status": "error",
                "database": "disconnected",
                "message": str(exc)
            }), 500

    # Socket.IO lifecycle events
    @socketio.on("connect")
    def handle_connect():
        print("[Socket.IO] Client connected to live crowd stream")

    @socketio.on("disconnect")
    def handle_disconnect():
        print("[Socket.IO] Client disconnected")

    @socketio.on("ping_server")
    def handle_ping(data):
        socketio.emit("pong_client", {"status": "alive", "echo": data})

    return app

app = create_app()

if __name__ == "__main__":
    port = int(os.getenv("PORT", 5000))
    print(f"Starting Train Crowd Server on 0.0.0.0:{port}...")
    socketio.run(app, host="0.0.0.0", port=port, debug=True, allow_unsafe_werkzeug=True)
