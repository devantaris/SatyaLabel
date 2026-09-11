"""
SQLAlchemy models — import all models so Base.metadata registers them.
"""
from app.models.scan import ScanRecord
from app.models.user import User, UserRole

__all__ = ["ScanRecord", "User", "UserRole"]
