const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const deployDir = path.join(root, 'deploy');
const assets = [
  ['website', '.'],
  ['app/build/web', 'app'],
  ['admin/dist', 'admin'],
];

for (const [source, destination] of assets) {
  const sourcePath = path.join(root, source);
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`Missing build output: ${sourcePath}`);
  }

  fs.cpSync(sourcePath, path.join(deployDir, destination), {
    recursive: true,
    force: true,
  });
}

fs.copyFileSync(
  path.join(root, 'staticwebapp.config.json'),
  path.join(deployDir, 'staticwebapp.config.json'),
);
