"""add_movies_and_showtimes

Revision ID: f4a1c8b2d7e1
Revises: e3b4c1d9a2f0
Create Date: 2026-03-22 12:00:00.000000

Adds:
  - movies table
  - movie_showtimes table
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "f4a1c8b2d7e1"
down_revision: Union[str, Sequence[str], None] = "e3b4c1d9a2f0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "movies",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("genre", sa.String(length=80), nullable=True),
        sa.Column("duration_min", sa.Integer(), nullable=True),
        sa.Column("language", sa.String(length=40), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_movies_id", "movies", ["id"])

    op.create_table(
        "movie_showtimes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("movie_id", sa.Integer(), nullable=False),
        sa.Column("theatre_name", sa.String(length=200), nullable=False),
        sa.Column("screen_number", sa.Integer(), nullable=True),
        sa.Column("show_times", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(["movie_id"], ["movies.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_movie_showtimes_id", "movie_showtimes", ["id"])
    op.create_index("ix_movie_showtimes_movie_id", "movie_showtimes", ["movie_id"])


def downgrade() -> None:
    op.drop_index("ix_movie_showtimes_movie_id", table_name="movie_showtimes")
    op.drop_index("ix_movie_showtimes_id", table_name="movie_showtimes")
    op.drop_table("movie_showtimes")
    op.drop_index("ix_movies_id", table_name="movies")
    op.drop_table("movies")
