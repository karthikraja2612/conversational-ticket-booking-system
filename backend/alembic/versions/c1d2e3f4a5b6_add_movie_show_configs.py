"""add_movie_show_configs

Revision ID: c1d2e3f4a5b6
Revises: f4a1c8b2d7e1
Create Date: 2026-03-23 12:00:00.000000

Adds:
  - movie_show_configs table
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "c1d2e3f4a5b6"
down_revision: Union[str, Sequence[str], None] = "f4a1c8b2d7e1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "movie_show_configs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("movie_id", sa.Integer(), nullable=True),
        sa.Column("movie_title", sa.String(length=200), nullable=False),
        sa.Column("venue_id", sa.Integer(), nullable=False),
        sa.Column("theatre_name", sa.String(length=200), nullable=False),
        sa.Column("theatre_location", sa.String(length=200), nullable=True),
        sa.Column("show_times", sa.JSON(), nullable=False),
        sa.Column("start_date", sa.DateTime(), nullable=False),
        sa.Column("end_date", sa.DateTime(), nullable=False),
        sa.Column("base_price", sa.Float(), nullable=False, server_default="0"),
        sa.Column("pricing_overrides", sa.JSON(), nullable=True),
        sa.Column("status", sa.Enum("draft", "published", "cancelled", name="eventstatus"), nullable=True),
        sa.Column("image_url", sa.String(length=300), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["movie_id"], ["movies.id"]),
        sa.ForeignKeyConstraint(["venue_id"], ["venues.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_movie_show_configs_id", "movie_show_configs", ["id"])
    op.create_index("ix_movie_show_configs_movie_id", "movie_show_configs", ["movie_id"])
    op.create_index("ix_movie_show_configs_venue_id", "movie_show_configs", ["venue_id"])


def downgrade() -> None:
    op.drop_index("ix_movie_show_configs_venue_id", table_name="movie_show_configs")
    op.drop_index("ix_movie_show_configs_movie_id", table_name="movie_show_configs")
    op.drop_index("ix_movie_show_configs_id", table_name="movie_show_configs")
    op.drop_table("movie_show_configs")
