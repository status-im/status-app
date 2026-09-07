"""Container mode for the headless peer.

status-go's own test client can run status-backend in a container it starts,
which leaves it owning the lifecycle, the shared library and the ports. All
this module does is point the client at our image and network.
"""
from __future__ import annotations

import os
import re
import subprocess
import tempfile
import threading

IMAGE_ENV = "STATUS_BACKEND_IMAGE"
PROJECT_ENV = "STATUS_BACKEND_DOCKER_PROJECT"

# scripts/peer_image.sh names the image statusgo-peer-<commit>, so the name is
# the peer's provenance and can be checked against the vendored pin. A tag or
# digest after the name is the registry's business, not the commit's.
MIN_SHA_PREFIX = 7
_REF_SUFFIX = re.compile(r"(:[\w][\w.\-]*)?(@sha256:[0-9a-f]{64})?$")
_SHA_IN_NAME = re.compile(r"statusgo-peer-([0-9a-f]{%d,40})$" % MIN_SHA_PREFIX)


class PeerProvenanceError(RuntimeError):
    pass

_scratch: str | None = None
_lock = threading.RLock()
_configured: tuple[str, str] | None = None


def image() -> str:
    return os.environ.get(IMAGE_ENV, "").strip()


def enabled() -> bool:
    return bool(image())


def scratch_dir() -> str:
    """Where the client's bind mounts land; without it they land in the cwd."""
    global _scratch
    with _lock:
        if _scratch is None:
            _scratch = tempfile.mkdtemp(prefix="e2e-peer-containers-")
        return _scratch


def e2e_root() -> str:
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def peer_logs_dir() -> str:
    return os.path.join(e2e_root(), "logs", "backend_peer")


def check_docker_resources(image_ref: str, project: str, docker_client=None) -> None:
    """Check resources before the client starts a peer: it maps a missing
    image to a plain RuntimeError before callers can distinguish it from a
    transient start failure."""
    import docker
    import docker.errors

    client = docker_client or docker.from_env()
    try:
        client.images.get(image_ref)
    except docker.errors.ImageNotFound as exc:
        raise RuntimeError(
            f"the peer image {image_ref!r} is not on this host. "
            "scripts/peer_image.sh <project> builds it."
        ) from exc
    try:
        client.networks.get(f"{project}_default")
    except docker.errors.NotFound as exc:
        raise RuntimeError(
            f"the docker network {project}_default is missing; "
            f"scripts/peer_image.sh {project} creates it."
        ) from exc


def vendored_status_go_sha(repo_root: str) -> str:
    """The status-go commit the app vendors, from the index rather than the checkout."""
    try:
        out = subprocess.run(
            ["git", "-C", repo_root, "ls-tree", "HEAD", "vendor/status-go"],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        raise PeerProvenanceError(f"could not read the vendored status-go pin: {exc}") from exc
    if out.returncode != 0 or not out.stdout.strip():
        raise PeerProvenanceError(
            f"could not read the vendored status-go pin from {repo_root}: "
            f"{out.stderr.strip() or 'no gitlink entry for vendor/status-go'}"
        )
    return out.stdout.split()[2]


def check_provenance(image_ref: str, vendored_sha: str) -> str:
    """The image has to come from the status-go commit this checkout vendors.
    That binds the peer to the checkout; nothing here reads the phone's APK."""
    name = _REF_SUFFIX.sub("", image_ref)
    match = _SHA_IN_NAME.search(name)
    if not match:
        raise PeerProvenanceError(
            f"{IMAGE_ENV}={image_ref!r} does not name the status-go commit it was "
            f"built from, so the peer's provenance is unknown. Build it with "
            f"scripts/peer_image.sh, which names it statusgo-peer-<commit>."
        )
    declared = match.group(1)
    if not vendored_sha.startswith(declared):
        raise PeerProvenanceError(
            f"the peer image {image_ref!r} was built from {declared} but this "
            f"checkout vendors {vendored_sha}. Rebuild it from the vendored pin."
        )
    return declared


def configure(config) -> None:
    """Switch the client from an external URL to a container of our image."""
    global _configured
    with _lock:
        image_ref = image()
        project = os.environ.get(PROJECT_ENV, "").strip()
        if _configured == (image_ref, project):
            return
        if not project:
            raise RuntimeError(
                f"{IMAGE_ENV} is set but {PROJECT_ENV} is not. The client attaches "
                "every container to <project>_default, so the name has to match the "
                "network the pipeline created."
            )
        from core.status_go_tf import repo_root

        check_provenance(image_ref, vendored_status_go_sha(repo_root()))
        check_docker_resources(image_ref, project)

        config.status_backend_urls = None
        config.docker_project_name = project
        config.docker_image = image_ref
        config.codecov_dir = os.path.join(scratch_dir(), "coverage")
        config.logs_dir = peer_logs_dir()
        _configured = (image_ref, project)
