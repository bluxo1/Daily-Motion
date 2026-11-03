# Reuse working-set values in an editable draft

This independently reviewable slice is based on main
`852eedf04de74110c6cf001699094c4c16f00fc1`. It does not include the unpublished
PR22 or owner-local PR23 preferences patch. Phase 0 and external qualification
remain open.

The active set editor offers **Use previous working set**. It selects the nearest
preceding completed working set in the same exercise instance, then previews the
source and target set ordinals, exact load/unit and repetitions. Confirmation
replaces the current pending slot's draft values and clears reported effort.
Cancel retains the existing draft. The user must deliberately record the set
after performing it. No additional prescribed slot, observation or command is
created by copying.

## State and safety

`SetEditor.copyPrevious` drains outstanding autosaves before reading a preview.
Controls are disabled while the confirmation is pending. The preview binds the
owner, installation, entire current workout projection, durable target draft and
current UI values. `SetDraftCopyRepository.applySetDraftCopy` rechecks the local
owner lock/disable state and bound data in the same SQLite transaction that writes
the draft. A changed projection or draft requires a fresh review. Late UI input is
retained rather than overwritten. SQL failure rolls back the draft write.

Only completed working sets from this exercise instance are eligible; warm-ups,
failed/partial/unperformed work and sets from other instances are excluded. The
original measurement string and unit are copied together without conversion.
Effort is blank, while the target's effort scale and outcome selection remain its
own. Planned prescriptions, recorded observations, revisions, outbox entries and
frozen request bodies are unchanged. Unknown draft fields are preserved through
refusal rather than silently dropped.

## Compatibility and rollout

No SQLite migration, backend endpoint, generated contract or server command is
introduced. This independent baseline remains reader schema 7. It must not be
used as a database downgrade for a file upgraded by the separate PR23 schema-8
patch. Integration with PR23 must retain reader 8 and requalify the combined
editor/repository changes; neither patch silently absorbs the other.

This implements draft reuse for an existing pending slot. Appending a new set or
copying a performed historical workout remains outside the accepted command
contract and is not implemented here. This feature does not enable routine
authoring in release builds or resolve retained synchronization conflicts.

## Executable evidence

`test/draft_copy_test.dart` exercises exact values and units, no invented effort
or observations, unchanged frozen bytes, rejected stale previews, rejected
unknown draft fields, owner/installation/lock boundaries, authoritative disable,
transaction failure and reopening a real SQLite file. Explicit recording is
separately checked after copying.

`test/draft_copy_widget_test.dart` exercises preview cancellation, confirmation,
deliberate recording and 320-pixel/200% text layouts in both themes. A controlled
repository barrier holds an older autosave: the preview cannot open until that
write completes, and the accepted copy remains the durable draft. No arbitrary
sleep establishes this ordering.

Additional widget controls exercise keyboard activation, disposal/account
replacement while the older save is held, and an actual SQLite-trigger failure
followed by retry. Error text does not expose the injected private SQL detail.
Navigation controls invoke each confirmation callback twice before the dialog
animation completes. Both choices remain on the training route; one decision
cannot pop the underlying editor or record a set.

The existing baseline editor fails the new copy-action widget control, with its
raw red output retained in the task evidence. Full-suite results and source
identities accompany the portable review bundle. Desktop widget/file tests do
not qualify native screen readers, physical process death or phone power loss.
