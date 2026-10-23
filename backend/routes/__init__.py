from backend.routes.trains import trains_bp
from backend.routes.stations import stations_bp
from backend.routes.crowd import crowd_bp
from backend.routes.tracking import tracking_bp
from backend.routes.simulation import simulation_bp
from backend.routes.auth import auth_bp

__all__ = [
    "trains_bp",
    "stations_bp",
    "crowd_bp",
    "tracking_bp",
    "simulation_bp",
    "auth_bp",
]
