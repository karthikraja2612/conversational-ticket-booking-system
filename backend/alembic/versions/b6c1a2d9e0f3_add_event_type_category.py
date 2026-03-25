"""add_event_type_category

Revision ID: b6c1a2d9e0f3
Revises: f4a1c8b2d7e1
Create Date: 2026-03-22 19:05:00.000000

Adds:
  - event_type column to events
  - backfills category values
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "b6c1a2d9e0f3"
down_revision: Union[str, Sequence[str], None] = "f4a1c8b2d7e1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "events",
        sa.Column("event_type", sa.String(length=30), nullable=False, server_default="others"),
    )

    op.execute(
        "UPDATE events SET event_type = 'movie' "
        "WHERE theatre_name IS NOT NULL AND theatre_name <> ''"
    )
    op.execute(
        "UPDATE events SET event_type = 'festival' "
        "WHERE event_type = 'others' AND (LOWER(name) LIKE '%festival%' OR LOWER(name) LIKE '%fest%')"
    )
    op.execute(
        "UPDATE events SET event_type = 'concert' "
        "WHERE event_type = 'others' AND ("
        "LOWER(name) LIKE '%concert%' OR LOWER(name) LIKE '%music%' OR LOWER(name) LIKE '%jazz%' "
        "OR LOWER(name) LIKE '%live%' OR LOWER(name) LIKE '%gig%')"
    )
    op.execute(
        "UPDATE events SET event_type = 'sports' "
        "WHERE event_type = 'others' AND ("
        "LOWER(name) LIKE '%sports%' OR LOWER(name) LIKE '%match%' OR LOWER(name) LIKE '%tournament%' "
        "OR LOWER(name) LIKE '%league%' OR LOWER(name) LIKE '%cup%' OR LOWER(name) LIKE '%stadium%')"
    )
    op.execute(
        "UPDATE events SET event_type = 'comedy' "
        "WHERE event_type = 'others' AND ("
        "LOWER(name) LIKE '%comedy%' OR LOWER(name) LIKE '%standup%' OR LOWER(name) LIKE '%stand-up%' "
        "OR LOWER(name) LIKE '%stand up%')"
    )


def downgrade() -> None:
    op.drop_column("events", "event_type")
