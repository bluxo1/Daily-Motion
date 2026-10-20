-- Approved, isolated restore target only; never apply to the source database.
-- Run in ONE transaction: psql --single-transaction --set=ON_ERROR_STOP=1 --file ...
-- Compare the restored archive first, then replay the external deletion ledger
-- and reconcile client branches before opening access. Preserve historical receipts.
-- Reconcile the erasure epoch against the independent ledger/high-water mark:
-- incrementing a rewound backup value alone may remain behind a cached client.
UPDATE training.owner_state
SET generation = gen_random_uuid(),
    minimum_position = position,
    erasure_epoch = erasure_epoch + 1;

DELETE FROM training.snapshots;
