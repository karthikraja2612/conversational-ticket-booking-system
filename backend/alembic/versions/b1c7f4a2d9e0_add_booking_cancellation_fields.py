"""add_booking_cancellation_fields

Revision ID: b1c7f4a2d9e0
Revises: a2f8c5d9e1b4
Create Date: 2026-03-19 10:00:00.000000

Adds:
  - bookings.cancellation_time
  - bookings.refund_status
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "b1c7f4a2d9e0"
down_revision: Union[str, Sequence[str], None] = "a2f8c5d9e1b4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    refund_status_enum = sa.Enum(
        "initiated",
        "completed",
        name="refundstatus",
    )
    op.add_column(
        "bookings",
        sa.Column("cancellation_time", sa.DateTime(), nullable=True),
    )
    op.add_column(
        "bookings",
        sa.Column("refund_status", refund_status_enum, nullable=True),
    )


def downgrade() -> None:
    refund_status_enum = sa.Enum(
        "initiated",
        "completed",
        name="refundstatus",
    )
    op.drop_column("bookings", "refund_status")
    op.drop_column("bookings", "cancellation_time")
    refund_status_enum.drop(op.get_bind(), checkfirst=True)
