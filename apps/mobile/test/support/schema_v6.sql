CREATE TABLE local_identity (
  singleton INTEGER NOT NULL PRIMARY KEY CHECK(singleton = 1),
  owner_id TEXT NOT NULL,
  installation_id TEXT NOT NULL,
  locked INTEGER NOT NULL DEFAULT 0 CHECK(locked IN (0,1)),
  cursor TEXT
);
CREATE TABLE sessions (
  id TEXT NOT NULL PRIMARY KEY,
  metadata TEXT NOT NULL,
  local_seq INTEGER NOT NULL,
  has_conflict INTEGER NOT NULL DEFAULT 0
  ,branch_base INTEGER
);
CREATE TABLE exercises (
  id TEXT NOT NULL PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL,
  definition TEXT NOT NULL
);
CREATE INDEX exercises_by_session ON exercises(session_id, ordinal);
CREATE TABLE workout_sets (
  id TEXT NOT NULL PRIMARY KEY,
  exercise_id TEXT NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  ordinal INTEGER NOT NULL,
  prescription TEXT NOT NULL,
  observation TEXT
);
CREATE INDEX sets_by_exercise ON workout_sets(exercise_id, ordinal);
CREATE TABLE local_observations (
  session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  local_seq INTEGER NOT NULL,
  set_id TEXT NOT NULL,
  payload TEXT NOT NULL,
  PRIMARY KEY(session_id, local_seq)
);
CREATE TABLE outbox (
  mutation_id TEXT NOT NULL PRIMARY KEY,
  session_id TEXT NOT NULL,
  local_seq INTEGER NOT NULL,
  predecessor_id TEXT,
  origin_base INTEGER NOT NULL,
  operation TEXT NOT NULL,
  frozen_body TEXT,
  accepted_revision INTEGER,
  state TEXT NOT NULL CHECK(state IN ('pending','acknowledged','conflict','rejected')),
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  request_digest TEXT,
  wire_version INTEGER NOT NULL DEFAULT 1 CHECK(wire_version IN (1,2)),
  origin_context TEXT,
  accepted_context TEXT,
  UNIQUE(session_id, local_seq)
);
CREATE TABLE shadows (
  session_id TEXT NOT NULL PRIMARY KEY,
  revision INTEGER NOT NULL,
  projection TEXT,
  recovery_context TEXT
);
CREATE TABLE drafts (
  set_id TEXT NOT NULL PRIMARY KEY REFERENCES workout_sets(id) ON DELETE CASCADE,
  values_json TEXT NOT NULL
);
CREATE TABLE rest_timers (
  session_id TEXT NOT NULL PRIMARY KEY REFERENCES sessions(id) ON DELETE CASCADE,
  anchor TEXT NOT NULL,
  deadline TEXT NOT NULL,
  monotonic_us INTEGER,
  continuity_id TEXT,
  uncertain INTEGER NOT NULL DEFAULT 0 CHECK(uncertain IN (0,1))
);
CREATE TABLE retired_ids (
  id TEXT NOT NULL PRIMARY KEY
);
CREATE TABLE sync_metadata (
  singleton INTEGER NOT NULL PRIMARY KEY CHECK(singleton=1),
  generation TEXT,
  position INTEGER NOT NULL DEFAULT 0,
  erasure_epoch INTEGER NOT NULL DEFAULT 0,
  remote_disabled INTEGER NOT NULL DEFAULT 0,
  retry_attempt INTEGER NOT NULL DEFAULT 0,
  next_attempt TEXT,
  last_error TEXT
);
CREATE TABLE bootstrap_stage (
  singleton INTEGER NOT NULL PRIMARY KEY CHECK(singleton=1),
  manifest TEXT NOT NULL
);
CREATE TABLE bootstrap_pages (
  page_index INTEGER NOT NULL PRIMARY KEY,
  body TEXT NOT NULL
);
CREATE TABLE recovery_state (
  singleton INTEGER NOT NULL PRIMARY KEY CHECK(singleton=1),
  required INTEGER NOT NULL DEFAULT 0 CHECK(required IN (0,1)),
  current_context TEXT,
  high_water INTEGER NOT NULL DEFAULT 0 CHECK(high_water >= 0)
);
CREATE TABLE historical_receipts (
  mutation_id TEXT NOT NULL PRIMARY KEY,
  evidence TEXT NOT NULL
);

-- Local-only planning. These rows never enter the workout transport outbox.
CREATE UNIQUE INDEX local_identity_owner ON local_identity(owner_id);
CREATE TABLE routines (
  id TEXT NOT NULL PRIMARY KEY,
  owner_id TEXT NOT NULL REFERENCES local_identity(owner_id),
  current_template_id TEXT,
  local_revision INTEGER NOT NULL CHECK(local_revision >= 0),
  UNIQUE(owner_id, id),
  FOREIGN KEY(owner_id, id, current_template_id)
    REFERENCES workout_templates(owner_id, routine_id, id)
);
CREATE TABLE workout_templates (
  id TEXT NOT NULL PRIMARY KEY,
  owner_id TEXT NOT NULL,
  routine_id TEXT NOT NULL,
  local_revision INTEGER NOT NULL CHECK(local_revision > 0),
  prescription TEXT NOT NULL,
  UNIQUE(owner_id, routine_id, id),
  UNIQUE(owner_id, routine_id, local_revision),
  FOREIGN KEY(owner_id, routine_id) REFERENCES routines(owner_id, id) ON DELETE CASCADE
);
CREATE TABLE routine_starts (
  attempt_id TEXT NOT NULL PRIMARY KEY,
  owner_id TEXT NOT NULL,
  routine_id TEXT NOT NULL,
  template_id TEXT NOT NULL,
  timezone TEXT NOT NULL,
  session_id TEXT NOT NULL UNIQUE,
  FOREIGN KEY(owner_id, routine_id, template_id)
    REFERENCES workout_templates(owner_id, routine_id, id) ON DELETE CASCADE
);

-- Private local catalog revisions never enter workout transport or bootstrap.
CREATE TABLE custom_exercise_definitions (
  owner_id TEXT NOT NULL REFERENCES local_identity(owner_id),
  variant_id TEXT NOT NULL,
  definition_revision INTEGER NOT NULL CHECK(definition_revision > 0),
  definition TEXT NOT NULL,
  PRIMARY KEY(owner_id, variant_id, definition_revision)
);
