"""Feed retention watermark and per-installation snapshot slots."""

from alembic import op

revision = "0002"
down_revision = "0001"


def upgrade() -> None:
    op.execute(
        "ALTER TABLE training.owner_state ADD COLUMN minimum_position bigint "
        "NOT NULL DEFAULT 0 CHECK(minimum_position >= 0)"
    )
    op.execute(
        "ALTER TABLE training.snapshots ADD COLUMN installation_id uuid "
        "NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'"
    )
    op.execute(
        "CREATE UNIQUE INDEX snapshot_installation ON training.snapshots(owner_id, installation_id)"
    )


def downgrade() -> None:
    op.execute("DROP INDEX training.snapshot_installation")
    op.execute("ALTER TABLE training.snapshots DROP COLUMN installation_id")
    op.execute("ALTER TABLE training.owner_state DROP COLUMN minimum_position")
