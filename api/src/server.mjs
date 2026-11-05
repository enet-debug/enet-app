import { createApp } from './app.mjs';

const port = Number(process.env.ENET_PORT || 8787);
const host = process.env.ENET_HOST || '127.0.0.1';
const { server, close } = createApp();
server.listen(port, host, () => {
  console.log('eNet API listening on http://' + host + ':' + port);
});
let stopping = false;
async function stop() {
  if (stopping) return;
  stopping = true;
  await close();
  process.exit(0);
}
process.on('SIGTERM', stop);
process.on('SIGINT', stop);
