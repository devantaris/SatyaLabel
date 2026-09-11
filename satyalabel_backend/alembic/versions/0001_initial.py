"""initial tables: users, scan_records with PostGIS

Revision ID: 0001_initial
Revises:
Create Date: 2026-09-11

"""
from collections.abc import Sequence

import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects.postgresql import JSONB, UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # PostGIS extension required for Geography columns
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")

    op.create_table(
        "users",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("email", sa.String(255), nullable=False, unique=True, index=True),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(255), nullable=True),
        sa.Column("role", sa.String(32), nullable=False, server_default="citizen"),
        sa.Column("badge_number", sa.String(64), nullable=True, unique=True),
        sa.Column("district", sa.String(128), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    op.create_table(
        "scan_records",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True, index=True),
        sa.Column("session_id", sa.String(64), nullable=True, index=True),
        sa.Column("image_path", sa.String(512), nullable=True),
        sa.Column("verdict", sa.String(32), nullable=False, index=True),
        sa.Column("violation_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("ocr_engine", sa.String(32), nullable=True),
        sa.Column("ocr_confidence", sa.Float(), nullable=True),
        sa.Column("extracted_fields", JSONB(), nullable=True),
        sa.Column("compliance_data", JSONB(), nullable=True),
        sa.Column("preprocess_diagnostics", JSONB(), nullable=True),
        sa.Column(
            "location",
            Geography(geometry_type="POINT", srid=4326),
            nullable=True,
        ),
        sa.Column("address_hint", sa.String(512), nullable=True),
        sa.Column("needs_review", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("report_generated", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )

    op.execute(
        "CREATE INDEX ix_scan_records_location ON scan_records USING GIST (location)"
    )


def downgrade() -> None:
    op.drop_index("ix_scan_records_location", table_name="scan_records")
    op.drop_table("scan_records")
    op.drop_table("users")
    op.execute("DROP EXTENSION IF EXISTS postgis")
