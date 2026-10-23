import sys
import os
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend.app import app
from backend.extensions import db
from sqlalchemy import text

with app.app_context():
    for tbl in ['stations', 'trains', 'coaches', 'crowd_reports', 'station_platforms', 'train_locations']:
        cols = db.session.execute(text(f"SELECT column_name FROM information_schema.columns WHERE table_name='{tbl}'")).fetchall()
        print(f"Table {tbl}:", [c[0] for c in cols])
