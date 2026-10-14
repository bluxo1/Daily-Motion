"""Minimal profile and irreversible owner retirement barrier, with forced RLS."""

from alembic import op

revision = "0003"
down_revision = "0002"


def upgrade() -> None:
    op.execute("""
      CREATE TABLE training.profiles (
        owner_id uuid PRIMARY KEY REFERENCES training.owner_state(owner_id),
        unit text NOT NULL DEFAULT 'kg' CHECK(unit IN ('kg','lb'))
      );
      CREATE TABLE training.account_retirements (
        owner_id uuid PRIMARY KEY, retired_at timestamptz NOT NULL
      );
      ALTER TABLE training.profiles ENABLE ROW LEVEL SECURITY;
      ALTER TABLE training.profiles FORCE ROW LEVEL SECURITY;
      CREATE POLICY owner_access ON training.profiles
        USING(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid)
        WITH CHECK(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid);
      ALTER TABLE training.account_retirements ENABLE ROW LEVEL SECURITY;
      ALTER TABLE training.account_retirements FORCE ROW LEVEL SECURITY;
      CREATE POLICY owner_read ON training.account_retirements FOR SELECT
        USING(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid);
      CREATE POLICY owner_retire ON training.account_retirements FOR INSERT
        WITH CHECK(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid);
      REVOKE ALL ON training.profiles, training.account_retirements FROM PUBLIC;
    """)


def downgrade() -> None:
    raise RuntimeError("Account retirement cannot be rolled back; use a forward fix")
