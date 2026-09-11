"""
Application configuration — reads from environment variables / .env file.
"""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # ── General ────────────────────────────────────────────────────────────────
    VERSION: str = "0.1.0"
    ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str = "change-me-in-production-use-openssl-rand-hex-32"

    # ── CORS ───────────────────────────────────────────────────────────────────
    ALLOWED_ORIGINS: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    # ── Database ───────────────────────────────────────────────────────────────
    DATABASE_URL: str = "postgresql+asyncpg://satyalabel:satyalabel@localhost:5432/satyalabel"
    DATABASE_URL_SYNC: str = "postgresql+psycopg2://satyalabel:satyalabel@localhost:5432/satyalabel"

    # ── Redis / Celery ─────────────────────────────────────────────────────────
    REDIS_URL: str = "redis://localhost:6379/0"
    CELERY_BROKER_URL: str = "redis://localhost:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://localhost:6379/1"

    # ── OCR ────────────────────────────────────────────────────────────────────
    TESSERACT_CMD: str = r"C:\Program Files\Tesseract-OCR\tesseract.exe"  # Windows path; override in .env
    OCR_CONFIDENCE_THRESHOLD: float = 0.60   # Below this → fallback to EasyOCR
    OCR_FALLBACK_THRESHOLD: float = 0.40     # Below this → flag for manual correction

    # ── File Storage ───────────────────────────────────────────────────────────
    UPLOAD_DIR: str = "uploads"
    MAX_IMAGE_SIZE_MB: int = 10

    # ── JWT Auth ───────────────────────────────────────────────────────────────
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 8  # 8 hours (inspector shift)

    # First-admin bootstrap (used once to seed the initial admin account)
    BOOTSTRAP_ADMIN_EMAIL: str | None = None
    BOOTSTRAP_ADMIN_PASSWORD: str | None = None


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings: Settings = get_settings()
