#!/usr/bin/env python3
"""Exercise real app recipes without building or changing native dependencies.

Run via make tests-nim-token-catalogue, which supplies the Qt bin directory.
Standalone runs require qmake and androiddeployqt on PATH.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class TokenCatalogueBuildTest(unittest.TestCase):
    def test_mobile_compiler_default(self):
        # Capture the real mobile script's compiler arguments without a cross-build.
        repo = Path(__file__).resolve().parent.parent
        git_dir = subprocess.check_output(
            ["git", "rev-parse", "--absolute-git-dir"], cwd=repo, text=True
        ).strip()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in (
                "scripts/version.sh",
                "vendor/status-go/scripts/version.sh",
                "vendor/nimbus-build-system/scripts/env.sh",
            ):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if name.endswith("env.sh"):
                    path.write_text(
                        '#!/bin/sh\nprintf "%s\\n" "$@" > "$TKL_TEST_ARGS"\n'
                    )
                else:
                    path.write_text("#!/bin/sh\necho fixture\n")
                path.chmod(0o755)
            (root / "bin").mkdir()
            # The build script copies the compiler output into LIB_DIR.
            for extension in (".so", ".a"):
                (root / "bin" / f"libnim_status_client{extension}").touch()
            for platform, extension in (("android", ".so"), ("ios", ".a")):
                for override in (None, "true", "false"):
                    with self.subTest(platform=platform, override=override):
                        env = dict(
                            os.environ,
                            STATUS_DESKTOP=str(root),
                            OS=platform,
                            LIB_DIR=str(root / "lib"),
                            LIB_EXT=extension,
                            TKL_TEST_ARGS=str(root / "args"),
                            GIT_DIR=git_dir,
                        )
                        env.pop("USE_NIM_TOKEN_LISTS", None)
                        if override is not None:
                            env["USE_NIM_TOKEN_LISTS"] = override
                        result = subprocess.run(
                            [
                                "bash",
                                str(repo / "mobile/scripts/buildNimStatusClient.sh"),
                            ],
                            env=env,
                            text=True,
                            capture_output=True,
                        )
                        self.assertEqual(
                            result.returncode, 0, result.stdout + result.stderr
                        )
                        args = (root / "args").read_text().splitlines()
                        self.assertIn(
                            f"-d:TOKEN_LISTS_USE_NIM_DEFAULT={override or 'true'}", args
                        )

    def test_runtime_rollback_keeps_native_support_in_default_builds(self):
        repo = Path(__file__).resolve().parent.parent
        for platform in ("desktop", "android", "ios"):
            for runtime in (None, "false", "true"):
                for override in (None, "false"):
                    with self.subTest(
                        platform=platform, runtime=runtime, override=override
                    ):
                        env = dict(os.environ)
                        # Each case owns its overrides, including when run by Make.
                        for key in (
                            "MAKEFLAGS",
                            "MFLAGS",
                            "MAKEOVERRIDES",
                            "GNUMAKEFLAGS",
                        ):
                            env.pop(key, None)
                        env.pop("USE_NIM_TOKEN_LISTS", None)
                        env.pop("STATUS_RUNTIME_TOKEN_LISTS_USE_NIM", None)
                        if runtime is not None:
                            env["STATUS_RUNTIME_TOKEN_LISTS_USE_NIM"] = runtime
                        command = [
                            "make",
                            "-n",
                            "MAKE=echo",
                            "-o",
                            "platform-cleanup",
                            "-f",
                            "Makefile",
                            "-f",
                            "-",
                        ]
                        config_recipe = "tkl-test-config:\n\t@echo $(NIM_PARAMS)\n"
                        if platform == "desktop":
                            command += [
                                "status-go",
                                "STATUSGO=/fixture/libstatus",
                                "NIMSDS_LIBFILE=/fixture/libsds",
                                "-o",
                                "/fixture/libsds",
                                "-o",
                                "deps",
                                "-o",
                                "force-rebuild-status-go",
                                "tkl-test-config",
                            ]
                            cwd = repo
                        else:
                            command += [
                                "/fixture/libstatus",
                                "STATUS_GO_LIB=/fixture/libstatus",
                                f"OS={platform}",
                                "ARCH=arm64",
                                "QT_MAJOR=6",
                                "QMAKE=qmake",
                                "ANDROID_SDK_ROOT=/fixture/sdk",
                                "ANDROID_NDK_ROOT=/fixture/ndk",
                                "/fixture/client",
                                "NIM_STATUS_CLIENT_LIB=/fixture/client",
                                "STATUS_DESKTOP_NIM_FILES=",
                            ]
                            for dependency in (
                                "STATUS_GO_STUB_LIB",
                                "STATUS_GO_SERVICE_LIB",
                                "STATUS_DESKTOP_RCC",
                                "OPENSSL_LIB",
                                "STATUS_Q_LIB",
                                "QRCODEGEN_LIB",
                            ):
                                command += [
                                    f"{dependency}=/fixture/{dependency}",
                                    "-o",
                                    f"/fixture/{dependency}",
                                ]
                            cwd = repo / "mobile"
                        if override is not None:
                            command.append(f"USE_NIM_TOKEN_LISTS={override}")
                        result = subprocess.run(
                            command,
                            cwd=cwd,
                            env=env,
                            text=True,
                            capture_output=True,
                            input=config_recipe,
                        )
                        self.assertEqual(
                            result.returncode,
                            0,
                            f"{command}\n{result.stdout}\n{result.stderr}",
                        )
                        enabled = override != "false"
                        expected = "true" if enabled else "false"
                        if platform == "desktop":
                            self.assertIn(
                                f"-d:TOKEN_LISTS_USE_NIM_DEFAULT={expected}",
                                result.stdout,
                            )
                            self.assertEqual(
                                "statusgo-shared-library-tkl" in result.stdout,
                                enabled,
                                result.stdout,
                            )
                        else:
                            self.assertIn(
                                f"USE_NIM_TOKEN_LISTS={expected}", result.stdout
                            )
                            client_command = result.stdout.split(
                                "Building Status Desktop Lib", 1
                            )[1]
                            self.assertIn(
                                f"USE_NIM_TOKEN_LISTS={expected}", client_command
                            )


if __name__ == "__main__":
    unittest.main()
