"""add_event_theatre_fields

Revision ID: e3b4c1d9a2f0
Revises: d2f9e4c1a7b0
Create Date: 2026-03-21 12:00:00.000000

Adds:
  - theatre_name, theatre_location to events
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "e3b4c1d9a2f0"
down_revision: Union[str, Sequence[str], None] = "d2f9e4c1a7b0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("events", sa.Column("theatre_name", sa.String(length=200), nullable=True))
    op.add_column("events", sa.Column("theatre_location", sa.String(length=200), nullable=True))


def downgrade() -> None:
    op.drop_column("events", "theatre_location")
    op.drop_column("events", "theatre_name")
