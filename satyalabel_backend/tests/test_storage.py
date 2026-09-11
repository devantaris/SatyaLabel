"""
Storage backend tests — local filesystem (tmp dir) and S3 (fake client).
No network access required.
"""
import pytest

from app.core.config import settings
from app.services import storage
from app.services.storage import get_storage


@pytest.fixture(autouse=True)
def fresh_storage_cache():
    """Each test gets a clean get_storage() singleton."""
    get_storage.cache_clear()
    yield
    get_storage.cache_clear()


class TestLocalStorage:
    def test_save_and_read_roundtrip(self, tmp_path, monkeypatch):
        monkeypatch.setattr(settings, "UPLOAD_DIR", str(tmp_path))
        store = storage.LocalStorage()

        stored = store.save(b"image-bytes-here", "abc123.jpg")
        assert stored == "abc123.jpg"
        assert (tmp_path / "abc123.jpg").read_bytes() == b"image-bytes-here"

        assert store.read("abc123.jpg") == b"image-bytes-here"

    def test_url_for_strips_directories(self, tmp_path, monkeypatch):
        monkeypatch.setattr(settings, "UPLOAD_DIR", str(tmp_path))
        store = storage.LocalStorage()
        assert store.url_for("abc123.jpg") == "/uploads/abc123.jpg"
        assert store.url_for("nested/abc123.jpg") == "/uploads/abc123.jpg"

    def test_creates_missing_upload_dir(self, tmp_path, monkeypatch):
        missing = tmp_path / "does" / "not" / "exist"
        monkeypatch.setattr(settings, "UPLOAD_DIR", str(missing))
        storage.LocalStorage().save(b"x" * 10, "a.jpg")
        assert (missing / "a.jpg").exists()

    def test_get_storage_defaults_to_local(self):
        assert isinstance(get_storage(), storage.LocalStorage)


class FakeBody:
    def __init__(self, data):
        self._data = data

    def read(self):
        return self._data


class FakeS3Client:
    """Minimal S3 client double: dict-backed put/get + presign stub."""

    def __init__(self):
        self.objects = {}
        self.presigned = []

    def put_object(self, Bucket, Key, Body):
        assert Bucket == "test-bucket"
        self.objects[Key] = Body

    def get_object(self, Bucket, Key):
        return {"Body": FakeBody(self.objects[Key])}

    def generate_presigned_url(self, method, Params, ExpiresIn):
        self.presigned.append((method, Params["Key"], ExpiresIn))
        return f"https://s3.test/{Params['Bucket']}/{Params['Key']}?sig=1"


class TestS3Storage:
    def _make(self, monkeypatch, **overrides):
        monkeypatch.setattr(settings, "STORAGE_BACKEND", "s3")
        monkeypatch.setattr(settings, "S3_BUCKET", "test-bucket")
        for key, value in overrides.items():
            monkeypatch.setattr(settings, key, value)
        return storage.S3Storage(client=FakeS3Client())

    def test_save_and_read_roundtrip(self, monkeypatch):
        store = self._make(monkeypatch)
        stored = store.save(b"picture", "scan-1.jpg")
        assert stored == "scan-1.jpg"
        assert store.read("scan-1.jpg") == b"picture"

    def test_public_url_base_used_when_configured(self, monkeypatch):
        store = self._make(
            monkeypatch, S3_PUBLIC_URL_BASE="https://cdn.example.com/bucket/"
        )
        url = store.url_for("scan-1.jpg")
        assert url == "https://cdn.example.com/bucket/scan-1.jpg"
        assert store._client.presigned == []  # no presign needed

    def test_presigned_url_when_no_public_base(self, monkeypatch):
        store = self._make(monkeypatch, S3_PRESIGN_EXPIRE_SECONDS=600)
        url = store.url_for("scan-1.jpg")
        assert url.startswith("https://s3.test/test-bucket/scan-1.jpg")
        assert store._client.presigned == [("get_object", "scan-1.jpg", 600)]

    def test_get_storage_requires_bucket(self, monkeypatch):
        monkeypatch.setattr(settings, "STORAGE_BACKEND", "s3")
        monkeypatch.setattr(settings, "S3_BUCKET", None)
        with pytest.raises(RuntimeError, match="S3_BUCKET"):
            get_storage()
