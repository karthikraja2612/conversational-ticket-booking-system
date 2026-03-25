"""add_chat_messages

Revision ID: d2f9e4c1a7b0
Revises: c8b2a6f1d4e3
Create Date: 2026-03-19 12:00:00.000000

Adds:
  - chat_messages table for per-user chat history
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "d2f9e4c1a7b0"
down_revision: Union[str, Sequence[str], None] = "c8b2a6f1d4e3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "chat_messages",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("sender", sa.String(length=10), nullable=False),
        sa.Column("content", sa.String(length=1000), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_chat_messages_id", "chat_messages", ["id"])
    op.create_index("ix_chat_messages_user_id", "chat_messages", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_chat_messages_user_id", table_name="chat_messages")
    op.drop_index("ix_chat_messages_id", table_name="chat_messages")
    op.drop_table("chat_messages")
