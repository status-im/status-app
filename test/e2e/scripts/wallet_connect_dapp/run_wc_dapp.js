import fs from 'node:fs';
import { SignClient } from '@walletconnect/sign-client';

const DEFAULT_PROJECT_ID = '87815d72a81d739d2a7ce15c2cfdefb3';
const DEFAULT_RELAY_URL = 'wss://relay.walletconnect.com';

function parseArgs(argv) {
  const args = {
    address: '',
    message: 'Status e2e WC sign',
    projectId: process.env.WALLET_CONNECT_PROJECT_ID || DEFAULT_PROJECT_ID,
    statusFile: '',
  };

  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    switch (value) {
    case '--address':
      args.address = argv[++index] || '';
      break;
    case '--message':
      args.message = argv[++index] || args.message;
      break;
    case '--status-file':
      args.statusFile = argv[++index] || '';
      break;
    default:
      break;
    }
  }

  if (!args.address) {
    throw new Error('--address is required');
  }
  if (!args.statusFile) {
    throw new Error('--status-file is required');
  }
  return args;
}

function writeStatus(statusFile, payload) {
  fs.writeFileSync(statusFile, `${JSON.stringify(payload)}\n`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  writeStatus(args.statusFile, { phase: 'starting' });

  const client = await SignClient.init({
    projectId: args.projectId,
    relayUrl: DEFAULT_RELAY_URL,
    metadata: {
      name: 'Status e2e WC dApp',
      description: 'E2E test dApp for WalletConnect personal_sign',
      url: 'https://status.app',
      icons: ['https://status.app/favicon.ico'],
    },
  });

  const { uri, approval } = await client.connect({
    requiredNamespaces: {
      eip155: {
        chains: ['eip155:1'],
        methods: ['personal_sign'],
        events: ['chainChanged', 'accountsChanged'],
      },
    },
  });

  if (!uri) {
    writeStatus(args.statusFile, { phase: 'error', error: 'No WalletConnect URI returned' });
    process.exit(1);
  }

  writeStatus(args.statusFile, { phase: 'uri_ready', uri });

  const session = await approval();
  writeStatus(args.statusFile, { phase: 'session_approved' });

  const hexMessage = `0x${Buffer.from(args.message, 'utf8').toString('hex')}`;
  const signature = await client.request({
    topic: session.topic,
    chainId: 'eip155:1',
    request: {
      method: 'personal_sign',
      params: [hexMessage, args.address],
    },
  });

  writeStatus(args.statusFile, { phase: 'sign_complete', signature });
  await client.disconnect({ topic: session.topic, reason: { code: 6000, message: 'e2e complete' } });
}

main().catch((error) => {
  const statusFile = process.argv.includes('--status-file')
    ? process.argv[process.argv.indexOf('--status-file') + 1]
    : '';
  if (statusFile) {
    writeStatus(statusFile, { phase: 'error', error: String(error) });
  } else {
    console.error(error);
  }
  process.exit(1);
});
