"""
Image storage abstraction — local disk (default) or S3-compatible object
storage (AWS S3, MinIO, etc.). Selected via STORAGE_BACKEND in settings.

Both backends implement the same three operations:
    save(data, filename) -> stored path/key recorded in scan_records.image_path
    read(stored_path)     -> bytes (used by the Celery worker)
    url_for(stored_path)  -> URL served to clients (or None if unavailable)
"""
from __future__ import annotations

import logging
import os
from functools import lru_cache
from pathlib import Path

from app.core.config import settings

logger = logging.getLogger(__name__)


class LocalStorage:
    """Stores images under UPLOAD_DIR; served by FastAPI's /uploads mount."""

    def save(self, data: bytes, filename: str) -> str:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
        path = os.path.join(settings.UPLOAD_DIR, filename)
        with open(path, "wb") as f:
            f.write(data)
        return filename

    def read(self, stored_path: str) -> bytes:
        with open(os.path.join(settings.UPLOAD_DIR, stored_path), "rb") as f:
            return f.read()

    def url_for(self, stored_path: str) -> str | None:
        return f"/uploads/{Path(stored_path).name}"


class S3Storage:
    """Stores images in an S3-compatible bucket.

    The client is injectable for tests. URLs are either
    {S3_PUBLIC_URL_BASE}/{key} (public buckets / CDN) or presigned
    (private buckets, S3_PRESIGN_EXPIRE_SECONDS validity).
    """

    def __init__(self, client=None):
        if client is not None:
            self._client = client
        else:
            import boto3  # optional dependency: pip install ".[s3]"

            self._client = boto3.client(
                "s3", endpoint_url=settings.S3_ENDPOINT_URL
            )
        self._bucket = settings.S3_BUCKET

    def save(self, data: bytes, filename: str) -> str:
        self._client.put_object(Bucket=self._bucket, Key=filename, Body=data)
        return filename

    def read(self, stored_path: str) -> bytes:
        response = self._client.get_object(
            Bucket=self._bucket, Key=stored_path
        )
        return response["Body"].read()

    def url_for(self, stored_path: str) -> str | None:
        if settings.S3_PUBLIC_URL_BASE:
            return f"{settings.S3_PUBLIC_URL_BASE.rstrip('/')}/{stored_path}"
        return self._client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self._bucket, "Key": stored_path},
            ExpiresIn=settings.S3_PRESIGN_EXPIRE_SECONDS,
        )


@lru_cache
def get_storage():
    """Storage backend singleton (re-run get_storage.cache_clear() in tests)."""
    if settings.STORAGE_BACKEND == "s3":
        if not settings.S3_BUCKET:
            raise RuntimeError("STORAGE_BACKEND=s3 requires S3_BUCKET to be set.")
        logger.info("Using S3 image storage (bucket %s)", settings.S3_BUCKET)
        return S3Storage()
    return LocalStorage()
