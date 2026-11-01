"""Owner-private immutable routine templates and explicit contract boundary.

No recovery control is activated or altered. Existing owner/feed/workout bytes
are retained. Old sync clients fail closed once an owner has routine content.
"""

from alembic import op

revision = "0005"
down_revision = "0004"


def upgrade() -> None:
    op.execute("""
      ALTER TABLE training.owner_state ADD COLUMN minimum_sync_contract integer
        NOT NULL DEFAULT 1 CHECK(minimum_sync_contract IN (1,3));
      ALTER TABLE training.snapshots ADD COLUMN sync_contract integer
        NOT NULL DEFAULT 1 CHECK(sync_contract IN (1,3));
      -- A pre-upgrade API process does not know routine publication. Hiding an
      -- upgraded owner's guard row makes ALL its old guarded entry points deny
      -- access, including bootstrap, rather than publish a filtered snapshot.
      -- Current code sets this transaction-local server capability itself;
      -- no request header, device ID or owner field can set a SQL capability.
      CREATE POLICY routine_capable_server ON training.owner_state AS RESTRICTIVE
        USING(minimum_sync_contract=1 OR current_setting('app.server_sync_contract',true)='3')
        WITH CHECK(minimum_sync_contract=1 OR current_setting('app.server_sync_contract',true)='3');
      CREATE TABLE training.routines (
        owner_id uuid NOT NULL REFERENCES training.owner_state(owner_id),
        id uuid NOT NULL,
        revision bigint NOT NULL CHECK(revision > 0),
        current_template_id uuid NOT NULL,
        PRIMARY KEY(owner_id,id)
      );
      CREATE TABLE training.routine_templates (
        owner_id uuid NOT NULL,
        id uuid NOT NULL,
        routine_id uuid NOT NULL,
        revision bigint NOT NULL CHECK(revision > 0),
        predecessor_template_id uuid,
        prescription jsonb NOT NULL,
        PRIMARY KEY(owner_id,id),
        UNIQUE(owner_id,routine_id,id),
        UNIQUE(owner_id,routine_id,revision),
        FOREIGN KEY(owner_id,routine_id) REFERENCES training.routines(owner_id,id)
          ON DELETE CASCADE,
        FOREIGN KEY(owner_id,routine_id,predecessor_template_id)
          REFERENCES training.routine_templates(owner_id,routine_id,id),
        CHECK((revision=1)=(predecessor_template_id IS NULL))
      );
      ALTER TABLE training.routines ADD CONSTRAINT routine_current_template
        FOREIGN KEY(owner_id,id,current_template_id)
        REFERENCES training.routine_templates(owner_id,routine_id,id)
        DEFERRABLE INITIALLY DEFERRED;
      CREATE INDEX routine_template_predecessor ON training.routine_templates
        (owner_id,routine_id,predecessor_template_id);
      CREATE FUNCTION training.keep_routine_template_immutable() RETURNS trigger
        LANGUAGE plpgsql SET search_path=pg_catalog AS $$
        BEGIN RAISE EXCEPTION 'Immutable routine template' USING ERRCODE='23514'; END;
        $$;
      REVOKE ALL ON FUNCTION training.keep_routine_template_immutable() FROM PUBLIC;
      CREATE TRIGGER immutable_template BEFORE UPDATE ON training.routine_templates
        FOR EACH ROW EXECUTE FUNCTION training.keep_routine_template_immutable();
    """)
    for table in ("routines", "routine_templates"):
        op.execute(f"ALTER TABLE training.{table} ENABLE ROW LEVEL SECURITY")
        op.execute(f"ALTER TABLE training.{table} FORCE ROW LEVEL SECURITY")
        op.execute(f"""
          CREATE POLICY owner_access ON training.{table}
            USING(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid)
            WITH CHECK(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid)
        """)
        op.execute(f"REVOKE ALL ON training.{table} FROM PUBLIC")
    op.execute("""
      -- The old retirement primitive treats an invisible owner row as absent.
      -- It must not commit a retirement marker while leaving an upgraded owner
      -- active. Require a capable server for that INSERT if planning exists;
      -- an unsupported transaction fails atomically, without claiming erasure.
      -- Routine rows remain owner-visible under their own RLS, even when the
      -- legacy owner guard is hidden. The owner-leading PK bounds this lookup.
      CREATE POLICY routine_capable_retirement ON training.account_retirements
        AS RESTRICTIVE FOR INSERT
        WITH CHECK(current_setting('app.server_sync_contract',true)='3' OR
          NOT EXISTS(SELECT 1 FROM training.routines r
            WHERE r.owner_id=account_retirements.owner_id));
    """)


def downgrade() -> None:
    raise RuntimeError("Routine planning data requires a forward fix; destructive downgrade denied")
