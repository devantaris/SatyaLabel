"""add status column, verdict nullable for async scans

Revision ID: 0002_scan_status
Revises: 0001_initial
Create Date: 2026-09-11

"""
from collections.abc import Sequence

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0002_scan_status"
down_revision: str | None = "0001_initial"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "scan_records",
        sa.Column("status", sa.String(32), nullable=False, server_default="COMPLETED"),
    )
    op.create_index("ix_scan_records_status", "scan_records", ["status"])
    op.alter_column("scan_records", "verdict", existing_type=sa.String(32), nullable=True)


def downgrade() -> None:
    op.alter_column(
        "scan_records", "verdict", existing_type=sa.String(32), nullable=False
    )
    op.drop_index("ix_scan_records_status", table_name="scan_records")
    op.drop_column("scan_records", "status")
