"""add_payment_pending_and_booking_failed

Revision ID: c8b2a6f1d4e3
Revises: b1c7f4a2d9e0
Create Date: 2026-03-19 11:00:00.000000

Adds:
  - payments.payment_status enum value: pending
  - bookings.status enum value: payment_failed
"""
from typing import Sequence, Union
from alembic import op

revision: str = "c8b2a6f1d4e3"
down_revision: Union[str, Sequence[str], None] = "b1c7f4a2d9e0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "postgresql":
        op.execute("ALTER TYPE paymentstatus ADD VALUE IF NOT EXISTS 'pending'")
        op.execute("ALTER TYPE bookingstatus ADD VALUE IF NOT EXISTS 'payment_failed'")
    elif dialect == "mysql":
        op.execute(
            "ALTER TABLE payments MODIFY COLUMN payment_status "
            "ENUM('success','failed','refunded','pending') NOT NULL"
        )
        op.execute(
            "ALTER TABLE bookings MODIFY COLUMN status "
            "ENUM('pending','confirmed','cancelled','payment_failed') NOT NULL"
        )


def downgrade() -> None:
    # Enum value removal is not safely reversible across engines.
    pass
