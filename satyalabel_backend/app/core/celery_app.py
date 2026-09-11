"""
Celery application — async OCR scan processing.

Worker: celery -A app.core.celery_app worker --loglevel=info
"""
from __future__ import annotations

import logging

from celery import Celery

from app.core.config import settings

logger = logging.getLogger(__name__)

celery_app = Celery(
    "satyalabel",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
    include=["app.core.scan_tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="Asia/Kolkata",
    enable_utc=True,
    # OCR tasks are CPU-heavy; long timeouts for EasyOCR fallbacks
    task_soft_time_limit=300,
    task_time_limit=360,
    # Don't pickle results
    result_accept_content=["json"],
    # Retry policy for broker hiccups
    broker_connection_retry_on_startup=True,
)
