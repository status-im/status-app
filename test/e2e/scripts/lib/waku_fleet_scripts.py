#!/usr/bin/env python3
"""Turn docker-compose.waku.yml into scripts that run the same nodes without Docker.

For hosts that cannot run the compose file: Windows (the nodes run under WSL1)
and macOS (the nodes run from the macOS release binary). The nodes share the
host's network there, so the compose service names become 127.0.0.1 and each
node listens on its own port.

    waku_fleet_scripts.py <compose file> <output dir>
                          [--install-dir DIR] [--log-dir DIR] [--wsl]

Writes one <service>.sh per node, services.txt, tag.txt (the node version the
compose file names) and, with --wsl, install.sh. A node script sources env.sh
from its own directory when there is one.
"""
import argparse
import pathlib
import re
import sys

# Docker's own resolver: there is none outside a compose network.
DROPPED = ('--dns-addrs-name-server=',)


def parse(compose_text):
    """Returns ({service: [args]}, {image tags}) for the services that have an entrypoint."""
    services, tags = {}, set()
    service = None
    in_entrypoint = False
    for line in compose_text.splitlines():
        header = re.match(r'^  ([A-Za-z0-9_-]+):\s*$', line)
        if header:
            service, in_entrypoint = header.group(1), False
            continue
        if service is None:
            continue
        image = re.match(r'^\s+image:\s*\S+:(\S+)\s*$', line)
        if image:
            tags.add(image.group(1))
        elif re.match(r'^\s+entrypoint:\s*\[\s*$', line):
            in_entrypoint = True
            services[service] = []
        elif in_entrypoint:
            if re.match(r'^\s+\]', line):
                in_entrypoint = False
                continue
            arg = re.match(r'^\s+"(.*)",?\s*$', line)
            if arg:
                services[service].append(arg.group(1))
    return services, tags


def flag_value(args, name):
    for arg in args:
        if arg.startswith(f'--{name}='):
            return arg.split('=', 1)[1]
    return None


def nodes(compose_text):
    """Returns {service: {tcp_port, rest_port, role}}: what scan_waku_fleet.py asks each node."""
    services, _ = parse(compose_text)
    return {
        service: {
            'tcp_port': int(flag_value(args, 'tcp-port')),
            'rest_port': int(flag_value(args, 'rest-port')),
            'role': 'store' if flag_value(args, 'store') == 'true' else 'bootstrap',
        }
        for service, args in services.items()
    }


def node_script(service, args, names, install_dir, log_dir, data_dir):
    binary, flags = args[0], args[1:]
    kept = []
    for flag in flags:
        if flag.startswith(DROPPED):
            continue
        for name in names:
            flag = flag.replace(f'/dns4/{name}/', '/ip4/127.0.0.1/')
        # In a container /tmp is the node's own; here the stores get the fleet's directory.
        flag = flag.replace('sqlite:///tmp/', f'sqlite://{data_dir}/')
        kept.append(flag)
    name = binary.rsplit('/', 1)[-1]
    lines = [
        '#!/bin/bash',
        'set -eu',
        'here=$(cd "$(dirname "$0")" && pwd)',
        'if [ -f "$here/env.sh" ]; then . "$here/env.sh"; fi',
        f"bin=$(find '{install_dir}' -type f -name {name} | head -n 1)",
        'exec "$bin" \\',
        *[f"  '{flag}' \\" for flag in kept],
        f"  > '{log_dir}/{service}.log' 2>&1",
    ]
    return '\n'.join(lines) + '\n'


def install_script(install_dir):
    return f"""#!/bin/bash
# For a Debian or Ubuntu under WSL. Run from the directory that holds
# waku.tar.gz and the node scripts.
set -eu
# The node loads libpq at run time, whatever store it uses.
export DEBIAN_FRONTEND=noninteractive
apt-get update -q > /tmp/apt.log 2>&1
apt-get install -y -q --no-install-recommends libpq5 >> /tmp/apt.log 2>&1
mkdir -p '{install_dir}'
tar xzf waku.tar.gz -C '{install_dir}'
cp ./*.sh '{install_dir}/'
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('compose', type=pathlib.Path)
    parser.add_argument('out', type=pathlib.Path)
    parser.add_argument('--install-dir', default='/opt/waku', help='where the node binary is unpacked')
    parser.add_argument('--log-dir', default='/tmp', help='where the nodes write their logs')
    parser.add_argument('--data-dir', default='/tmp', help='where the store nodes keep their messages')
    parser.add_argument('--wsl', action='store_true', help='also write install.sh for a Debian or Ubuntu under WSL')
    args = parser.parse_args()

    services, tags = parse(args.compose.read_text(encoding='utf-8'))
    if not services:
        sys.exit(f'no service with an entrypoint in {args.compose}')
    if len(tags) != 1:
        sys.exit(f'{args.compose} names more than one node version: {sorted(tags)}')
    args.out.mkdir(parents=True, exist_ok=True)

    def write(name, text):
        (args.out / name).write_text(text, encoding='utf-8', newline='\n')

    for service, node_args in services.items():
        write(f'{service}.sh', node_script(service, node_args, services, args.install_dir, args.log_dir, args.data_dir))
    if args.wsl:
        write('install.sh', install_script(args.install_dir))
    write('services.txt', '\n'.join(services) + '\n')
    write('tag.txt', tags.pop() + '\n')
    print('nodes: ' + ', '.join(services))


if __name__ == '__main__':
    main()
