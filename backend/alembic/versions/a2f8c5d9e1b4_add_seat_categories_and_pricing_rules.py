"""add_seat_categories_and_pricing_rules

Revision ID: a2f8c5d9e1b4
Revises: 664031ccf339
Create Date: 2026-03-11 10:00:00.000000

Adds:
  - seat_categories table  (id, name, multiplier)
  - pricing_rules table    (id, event_id, seat_category_id, price_override)
  - seats.category_id FK → seat_categories.id
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "a2f8c5d9e1b4"
down_revision: Union[str, Sequence[str], None] = "664031ccf339"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── seat_categories ───────────────────────────────────────────────────────
    op.create_table(
        "seat_categories",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(50), nullable=False),
        sa.Column("multiplier", sa.Float(), nullable=False, server_default="1.0"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )
    op.create_index("ix_seat_categories_id", "seat_categories", ["id"])

    # Seed two default categories so the FK on seats is immediately usable
    op.execute(
        "INSERT INTO seat_categories (name, multiplier) VALUES ('standard', 1.0), ('vip', 2.0)"
    )

    # ── pricing_rules ─────────────────────────────────────────────────────────
    op.create_table(
        "pricing_rules",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("event_id", sa.Integer(), nullable=False),
        sa.Column("seat_category_id", sa.Integer(), nullable=False),
        sa.Column("price_override", sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"]),
        sa.ForeignKeyConstraint(["seat_category_id"], ["seat_categories.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_pricing_rules_id", "pricing_rules", ["id"])

    # ── seats.category_id ─────────────────────────────────────────────────────
    op.add_column("seats", sa.Column("category_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_seats_category_id",
        "seats",
        "seat_categories",
        ["category_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint("fk_seats_category_id", "seats", type_="foreignkey")
    op.drop_column("seats", "category_id")
    op.drop_index("ix_pricing_rules_id", table_name="pricing_rules")
    op.drop_table("pricing_rules")
    op.drop_index("ix_seat_categories_id", table_name="seat_categories")
    op.drop_table("seat_categories")
