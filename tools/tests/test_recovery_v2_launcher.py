import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from run_recovery_v2_local import clean_environment, main  # noqa: E402


class RecoveryLauncherTest(unittest.TestCase):
    def test_inherited_provider_libpq_and_pytest_overrides_are_removed(self) -> None:
        source = {
            "SystemRoot": "synthetic-system",
            "PATH": "synthetic-path",
            "DM_TEST_ADMIN_URL": "synthetic-unapproved-target",
            "PGHOST": "remote.test",
            "PGOPTIONS": "synthetic-role-override",
            "PGPASSWORD": "synthetic-password",
            "AWS_ACCESS_KEY_ID": "synthetic-key",
            "SUPABASE_SERVICE_ROLE_KEY": "synthetic-key",
            "GOOGLE_APPLICATION_CREDENTIALS": "synthetic-credential-file",
            "PYTEST_ADDOPTS": "synthetic-case-omission",
        }
        self.assertEqual(
            clean_environment(source), {"SystemRoot": "synthetic-system", "PATH": "synthetic-path"}
        )

    def test_missing_opt_in_fails_before_any_subprocess(self) -> None:
        with patch.object(sys, "argv", ["runner", "--pg-bin", "."]):
            with patch("subprocess.run") as run, contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as error:
                    main()
            self.assertEqual(error.exception.code, 2)
            run.assert_not_called()

    def test_incomplete_postgres_tools_fail_before_any_subprocess(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(sys, "argv", ["runner", "--run-local", "--pg-bin", directory]):
                with patch("subprocess.run") as run, contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as error:
                        main()
                self.assertEqual(error.exception.code, 2)
                run.assert_not_called()

    def test_full_regression_requires_explicit_flutter_and_cache(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            for name in ["postgres.exe", "initdb.exe", "pg_ctl.exe", "createdb.exe"]:
                (Path(directory) / name).write_text("synthetic marker; never executed")
            with patch.object(
                sys, "argv", ["runner", "--run-local", "--pg-bin", directory, "--full-python"]
            ):
                with patch("subprocess.run") as run, contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as error:
                        main()
                self.assertEqual(error.exception.code, 2)
                run.assert_not_called()


if __name__ == "__main__":
    unittest.main()
