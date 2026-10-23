from flask import Blueprint, jsonify, request
from backend.services.storage import register_or_login_user, get_user_by_id

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")

@auth_bp.post("/login")
def login_or_register():
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    phone_or_email = (data.get("phone_or_email") or data.get("email") or data.get("phone") or "").strip()

    if not name or not phone_or_email:
        return jsonify({
            "success": False,
            "message": "Both name and phone/email are required to sign in."
        }), 400

    try:
        user = register_or_login_user(name, phone_or_email)
        return jsonify({
            "success": True,
            "message": "Login successful",
            "user": user
        }), 200
    except Exception as e:
        return jsonify({
            "success": False,
            "message": f"Could not sign in: {str(e)}"
        }), 500

@auth_bp.get("/user/<int:user_id>")
def get_user(user_id):
    user = get_user_by_id(user_id)
    if not user:
        return jsonify({"success": False, "message": "User not found"}), 404
    return jsonify({"success": True, "user": user})
