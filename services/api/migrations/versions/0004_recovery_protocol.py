"""Add closed recovery control and owner-private attempt/publication metadata.

Capability only: no environment is registered or activated by migration.
Production certification/activation remains unavailable until its prerequisites
are implemented and accepted. Legacy rows/receipts are never restamped.
"""

from alembic import op

revision = "0004"
down_revision = "0003"


def upgrade() -> None:
    op.execute("""
      CREATE SCHEMA recovery;
      REVOKE ALL ON SCHEMA recovery FROM PUBLIC;
      CREATE TABLE recovery.control (
        singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
        environment_id uuid NOT NULL,
        activation_serial bigint NOT NULL CHECK(activation_serial > 0),
        incarnation uuid NOT NULL,
        target_digest text NOT NULL CHECK(target_digest ~ '^[0-9a-f]{64}$'),
        manifest_digest text NOT NULL CHECK(manifest_digest ~ '^[0-9a-f]{64}$'),
        state text NOT NULL DEFAULT 'CLOSED' CHECK(state IN ('CLOSED','RECONCILING','OPEN'))
      );
      REVOKE ALL ON recovery.control FROM PUBLIC;

      CREATE TABLE training.recovery_owners (
        owner_id uuid PRIMARY KEY,
        environment_id uuid NOT NULL,
        incarnation uuid NOT NULL,
        generation uuid NOT NULL,
        evidence_order bigint NOT NULL DEFAULT 0 CHECK(evidence_order >= 0),
        evidence_digest text NOT NULL CHECK(evidence_digest ~ '^[0-9a-f]{64}$'),
        visible_position bigint NOT NULL DEFAULT 0 CHECK(visible_position >= 0),
        erasure_high_water bigint NOT NULL DEFAULT 0 CHECK(erasure_high_water >= 0),
        hold_attempt uuid
      );
      CREATE TABLE training.recovery_attempts (
        owner_id uuid NOT NULL REFERENCES training.recovery_owners(owner_id),
        attempt_id uuid NOT NULL,
        mutation_id uuid NOT NULL,
        aggregate_id uuid,
        schema_version integer NOT NULL CHECK(schema_version=2),
        environment_id uuid NOT NULL,
        incarnation uuid NOT NULL,
        generation uuid NOT NULL,
        activation_serial bigint NOT NULL CHECK(activation_serial > 0),
        request_digest text NOT NULL CHECK(request_digest ~ '^[0-9a-f]{64}$'),
        state text NOT NULL CHECK(state IN
          ('RESERVED','EFFECT_COMMITTED','PUBLISHED','UNRESOLVED','NOT_COMMITTED')),
        frozen_request jsonb,
        result jsonb,
        committed_marker jsonb,
        certificate jsonb,
        CONSTRAINT recovery_effect_binding_present CHECK(
          state NOT IN ('EFFECT_COMMITTED','PUBLISHED')
          OR (result IS NOT NULL AND committed_marker IS NOT NULL)),
        CONSTRAINT recovery_reserved_has_no_result CHECK(
          state<>'RESERVED' OR
          (result IS NULL AND committed_marker IS NULL AND certificate IS NULL)),
        PRIMARY KEY(owner_id,attempt_id),
        UNIQUE(owner_id,mutation_id)
      );
      CREATE FUNCTION recovery.guard_attempt_binding() RETURNS trigger
        LANGUAGE plpgsql AS $$ BEGIN
          IF ROW(NEW.owner_id,NEW.attempt_id,NEW.mutation_id,NEW.aggregate_id,NEW.schema_version,
                 NEW.environment_id,NEW.incarnation,NEW.generation,NEW.activation_serial,
                 NEW.request_digest) IS DISTINCT FROM
             ROW(OLD.owner_id,OLD.attempt_id,OLD.mutation_id,OLD.aggregate_id,OLD.schema_version,
                 OLD.environment_id,OLD.incarnation,OLD.generation,OLD.activation_serial,
                 OLD.request_digest)
             OR (OLD.committed_marker IS NOT NULL AND
                 (NEW.committed_marker IS DISTINCT FROM OLD.committed_marker
                  OR NEW.result IS DISTINCT FROM OLD.result))
             OR (NEW.frozen_request IS DISTINCT FROM OLD.frozen_request AND NOT
                 (NEW.frozen_request IS NULL AND NEW.state IN ('PUBLISHED','NOT_COMMITTED')))
          THEN RAISE EXCEPTION 'Recovery attempt binding is immutable'; END IF;
          RETURN NEW;
        END $$;
      REVOKE ALL ON FUNCTION recovery.guard_attempt_binding() FROM PUBLIC;
      CREATE TRIGGER recovery_attempt_binding BEFORE UPDATE ON training.recovery_attempts
        FOR EACH ROW EXECUTE FUNCTION recovery.guard_attempt_binding();
      ALTER TABLE training.recovery_owners ADD CONSTRAINT recovery_hold_attempt
        FOREIGN KEY(owner_id,hold_attempt)
        REFERENCES training.recovery_attempts(owner_id,attempt_id)
        DEFERRABLE INITIALLY DEFERRED;
      CREATE UNIQUE INDEX recovery_one_active_attempt
        ON training.recovery_attempts(owner_id)
        WHERE state IN ('RESERVED','EFFECT_COMMITTED','UNRESOLVED');
      ALTER TABLE training.recovery_owners ENABLE ROW LEVEL SECURITY;
      ALTER TABLE training.recovery_owners FORCE ROW LEVEL SECURITY;
      CREATE POLICY owner_access ON training.recovery_owners
        USING(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid)
        WITH CHECK(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid);
      ALTER TABLE training.recovery_attempts ENABLE ROW LEVEL SECURITY;
      ALTER TABLE training.recovery_attempts FORCE ROW LEVEL SECURITY;
      CREATE POLICY owner_access ON training.recovery_attempts
        USING(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid)
        WITH CHECK(owner_id=nullif(current_setting('app.owner_id',true),'')::uuid);
      REVOKE ALL ON training.recovery_owners,training.recovery_attempts FROM PUBLIC;
    """)


def downgrade() -> None:
    raise RuntimeError("Recovery provenance and publication holds require a compatible forward fix")
