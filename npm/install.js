/**
 * BeamJS postinstall script
 * Extracts the bundled BEAM release tarball into the release/ directory.
 */

const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");

const packageDir = __dirname;
const tarball = path.join(packageDir, "release.tar.gz");
const releaseDir = path.join(packageDir, "release");

if (!fs.existsSync(tarball)) {
  console.log("beamjs: release.tar.gz not found, skipping extraction.");
  process.exit(0);
}

if (fs.existsSync(path.join(releaseDir, "bin", "beamjs"))) {
  // Already extracted
  process.exit(0);
}

console.log("beamjs: extracting release...");

try {
  fs.mkdirSync(releaseDir, { recursive: true });
  execSync(`tar xzf "${tarball}" -C "${releaseDir}"`, { stdio: "pipe" });

  // Make the release bin executable
  const releaseBin = path.join(releaseDir, "bin", "beamjs");
  if (fs.existsSync(releaseBin)) {
    fs.chmodSync(releaseBin, 0o755);
  }

  // Also make ERTS bin executables
  const ertsDir = fs.readdirSync(releaseDir).find(d => d.startsWith("erts-"));
  if (ertsDir) {
    const ertsBin = path.join(releaseDir, ertsDir, "bin");
    if (fs.existsSync(ertsBin)) {
      for (const file of fs.readdirSync(ertsBin)) {
        const filePath = path.join(ertsBin, file);
        try { fs.chmodSync(filePath, 0o755); } catch {}
      }
    }
  }

  console.log("beamjs: release extracted successfully.");
} catch (e) {
  console.error("beamjs: failed to extract release:", e.message);
  process.exit(1);
}
