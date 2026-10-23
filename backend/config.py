import os
from dotenv import load_dotenv

# Search both backend/.env and current directory .env
env_paths = [
    os.path.join(os.path.dirname(__file__), ".env"),
    os.path.join(os.path.dirname(__file__), "..", ".env"),
    os.path.abspath(".env")
]

for p in env_paths:
    if os.path.exists(p):
        load_dotenv(p, override=True)
        break

class Config:
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg://train_app:theevandi@localhost:5432/train_crowd"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SECRET_KEY = os.getenv("SECRET_KEY", "train-crowd-secret-key-mca-project")
