CREATE SCHEMA training;
CREATE TABLE training.owner_state (
  owner_id uuid PRIMARY KEY,
  status text NOT NULL CHECK (status IN ('active', 'deleting')),
  generation uuid NOT NULL,
  position bigint NOT NULL DEFAULT 0 CHECK (position >= 0),
  erasure_epoch bigint NOT NULL DEFAULT 0 CHECK (erasure_epoch >= 0)
);
CREATE TABLE training.workouts (
  owner_id uuid NOT NULL, id uuid NOT NULL, revision bigint NOT NULL CHECK (revision > 0),
  name varchar(120) NOT NULL, timezone varchar(80) NOT NULL,
  status text NOT NULL CHECK (status IN ('active', 'completed', 'abandoned')),
  started_at text NOT NULL, ended_at text,
  PRIMARY KEY (owner_id, id),
  FOREIGN KEY (owner_id) REFERENCES training.owner_state(owner_id)
);
CREATE TABLE training.exercises (
  owner_id uuid NOT NULL, id uuid NOT NULL, session_id uuid NOT NULL, ordinal integer NOT NULL,
  definition jsonb NOT NULL, PRIMARY KEY (owner_id, id),
  FOREIGN KEY (owner_id, session_id) REFERENCES training.workouts(owner_id, id) ON DELETE CASCADE
);
CREATE INDEX exercises_session ON training.exercises(owner_id, session_id, ordinal);
CREATE TABLE training.sets (
  owner_id uuid NOT NULL, id uuid NOT NULL, exercise_id uuid NOT NULL, ordinal integer NOT NULL,
  prescription jsonb NOT NULL, observation jsonb, PRIMARY KEY (owner_id, id),
  FOREIGN KEY (owner_id, exercise_id) REFERENCES training.exercises(owner_id, id) ON DELETE CASCADE
);
CREATE INDEX sets_exercise ON training.sets(owner_id, exercise_id, ordinal);
CREATE TABLE training.observations (
  owner_id uuid NOT NULL, session_id uuid NOT NULL, revision bigint NOT NULL, set_id uuid NOT NULL,
  position bigint NOT NULL, generation uuid NOT NULL, payload jsonb NOT NULL,
  PRIMARY KEY (owner_id, session_id, revision)
);
CREATE TABLE training.receipts (
  owner_id uuid NOT NULL, mutation_id uuid NOT NULL, digest varchar(64) NOT NULL,
  acknowledgement jsonb NOT NULL, PRIMARY KEY (owner_id, mutation_id)
);
CREATE TABLE training.changes (
  owner_id uuid NOT NULL, position bigint NOT NULL, session_id uuid NOT NULL,
  created_at timestamptz NOT NULL, body jsonb NOT NULL, PRIMARY KEY (owner_id, position)
);
CREATE TABLE training.retired_ids (
  owner_id uuid NOT NULL, id uuid NOT NULL, PRIMARY KEY (owner_id, id)
);
CREATE TABLE training.snapshots (
  owner_id uuid NOT NULL, id uuid NOT NULL, generation uuid NOT NULL, erasure_epoch bigint NOT NULL,
  position bigint NOT NULL, expires_at timestamptz NOT NULL, pages jsonb NOT NULL,
  PRIMARY KEY (owner_id, id)
);
DO $$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'owner_state','workouts','exercises','sets','observations','receipts','changes','retired_ids','snapshots'
  ] LOOP
    EXECUTE format('ALTER TABLE training.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('ALTER TABLE training.%I FORCE ROW LEVEL SECURITY', table_name);
    EXECUTE format(
      'CREATE POLICY owner_access ON training.%I USING (owner_id = nullif(current_setting(''app.owner_id'', true), '''')::uuid) WITH CHECK (owner_id = nullif(current_setting(''app.owner_id'', true), '''')::uuid)',
      table_name
    );
  END LOOP;
END $$;
REVOKE ALL ON SCHEMA training FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA training FROM PUBLIC;
