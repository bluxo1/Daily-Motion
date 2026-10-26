// Same VM product constant used by Flutter's kReleaseMode. Kept independent
// of widgets so the release boundary can also be exercised in a product VM.
bool internalRoutineAccess(bool requested) =>
    !const bool.fromEnvironment('dart.vm.product') && requested;
