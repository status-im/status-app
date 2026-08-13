#!/usr/bin/env python3

import os
import argparse
import json
import subprocess
import sys
import time
import urllib.request


def get_host_port(project, service, container_port):
    result = subprocess.run(
        ["docker", "compose", "-p", project, "port", service, str(container_port)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"Failed to get host port for {service}:{container_port}: {result.stderr}")
    return result.stdout.strip().split(":")[-1]


def get_node_info(port, retries=30, delay=2):
    url = f"http://127.0.0.1:{port}/debug/v1/info"
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=5) as resp:
                return json.loads(resp.read())
        except Exception:
            if attempt < retries - 1:
                time.sleep(delay)
    raise RuntimeError(f"Could not reach {url} after {retries} attempts")


def extract_peer_id(listen_addrs):
    for addr in listen_addrs:
        if "/p2p/" in addr:
            return addr.split("/p2p/")[-1]
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", default="e2e-fleet")
    parser.add_argument("--fleet-name", default="status-app.test")
    parser.add_argument("--cluster-id", type=int, default=16)
    parser.add_argument("--output", default="assets/local-waku-fleets-config.json")
    args = parser.parse_args()

    services = {
        "boot-1":  {"tcp_port": 39001, "rest_port": 8645, "role": "bootstrap"},
        "store":   {"tcp_port": 39002, "rest_port": 8646, "role": "store"},
        "store-2": {"tcp_port": 39003, "rest_port": 8647, "role": "store"},
    }

    waku_nodes = []
    disc_v5_nodes = []
    store_nodes = []

    for service, cfg in services.items():
        host_rest = get_host_port(args.project, service, cfg["rest_port"])
        host_tcp = get_host_port(args.project, service, cfg["tcp_port"])

        print(f"{service}: REST={host_rest}, TCP={host_tcp}")

        info = get_node_info(host_rest)
        enr = info["enrUri"]
        peer_id = extract_peer_id(info["listenAddresses"])

        if not peer_id:
            print(f"ERROR: Could not extract peer ID for {service}", file=sys.stderr)
            sys.exit(1)

        addr = f"/ip4/127.0.0.1/tcp/{host_tcp}/p2p/{peer_id}"

        if cfg["role"] == "bootstrap":
            waku_nodes.append(enr)
            disc_v5_nodes.append(enr)

        if cfg["role"] == "store":
            store_nodes.append({
                "id": service,
                "enr": enr,
                "addr": addr,
                "fleet": "status-desktop.test"
            })

    config = {
        args.fleet_name: {
            "clusterId": args.cluster_id,
            "wakuNodes": waku_nodes,
            "discV5BootstrapNodes": disc_v5_nodes,
            "storeNodes": store_nodes
        }
    }

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w") as f:
        json.dump(config, f, indent=2)

    print(f"Fleet config written to {args.output}")


if __name__ == "__main__":
    main()