"""Initial private training schema, composite ownership and fail-closed RLS."""

from pathlib import Path

from alembic import op

revision = "0001"
down_revision = None


def upgrade() -> None:
    op.execute(Path(__file__).with_name("0001_schema.sql").read_text(encoding="utf-8"))


def downgrade() -> None:
    op.execute("DROP SCHEMA training CASCADE")
