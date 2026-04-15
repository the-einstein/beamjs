/**
 * BeamJS postinstall script
 *
 * 1. If a bundled release.tar.gz exists (linux-x64), extract it.
 * 2. Otherwise, download the correct platform binary from GitHub Releases.
 */

const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");
const https = require("https");

const packageDir = __dirname;
const packageJson = require(path.join(packageDir, "package.json"));
const version = packageJson.version;
const releaseDir = path.join(packageDir, "release");
const releaseBin = path.join(releaseDir, "bin", "beamjs");

// Already installed
if (fs.existsSync(releaseBin)) {
  process.exit(0);
}

// Platform detection
const PLATFORMS = {
  "linux-x64": "beamjs-linux-x64.tar.gz",
  "darwin-arm64": "beamjs-darwin-arm64.tar.gz",
  "darwin-x64": "beamjs-darwin-x64.tar.gz",
};

const platformKey = `${process.platform}-${process.arch}`;
const artifactName = PLATFORMS[platformKey];

if (!artifactName) {
  console.error(`beamjs: unsupported platform: ${platformKey}`);
  console.error(`beamjs: supported platforms: ${Object.keys(PLATFORMS).join(", ")}`);
  process.exit(1);
}

// Try bundled tarball first (linux-x64 is bundled in the npm package)
const bundledTarball = path.join(packageDir, "release.tar.gz");
if (fs.existsSync(bundledTarball) && platformKey === "linux-x64") {
  console.log("beamjs: extracting bundled release...");
  extractRelease(bundledTarball);
  process.exit(0);
}

// Download from GitHub Releases
const url = `https://github.com/the-einstein/beamjs/releases/download/v${version}/${artifactName}`;
const tarballPath = path.join(packageDir, artifactName);

console.log(`beamjs: downloading ${artifactName} for ${platformKey}...`);

download(url, tarballPath)
  .then(() => {
    console.log("beamjs: extracting release...");
    extractRelease(tarballPath);
    // Clean up downloaded tarball
    try { fs.unlinkSync(tarballPath); } catch {}
    console.log("beamjs: installed successfully.");
  })
  .catch((err) => {
    console.error(`beamjs: failed to download release: ${err.message}`);
    console.error(`beamjs: url: ${url}`);
    console.error("");
    console.error("If you're on an unsupported platform, you can build from source:");
    console.error("  https://github.com/the-einstein/beamjs#from-source");
    process.exit(1);
  });

function extractRelease(tarball) {
  try {
    fs.mkdirSync(releaseDir, { recursive: true });
    execSync(`tar xzf "${tarball}" -C "${releaseDir}"`, { stdio: "pipe" });

    // Make release bin executable
    if (fs.existsSync(releaseBin)) {
      fs.chmodSync(releaseBin, 0o755);
    }

    // Make ERTS bin executables
    const entries = fs.readdirSync(releaseDir);
    const ertsDir = entries.find((d) => d.startsWith("erts-"));
    if (ertsDir) {
      const ertsBin = path.join(releaseDir, ertsDir, "bin");
      if (fs.existsSync(ertsBin)) {
        for (const file of fs.readdirSync(ertsBin)) {
          try { fs.chmodSync(path.join(ertsBin, file), 0o755); } catch {}
        }
      }
    }
  } catch (e) {
    console.error("beamjs: extraction failed:", e.message);
    process.exit(1);
  }
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    followRedirects(url, (res) => {
      if (res.statusCode !== 200) {
        fs.unlinkSync(dest);
        reject(new Error(`HTTP ${res.statusCode} from ${url}`));
        return;
      }
      res.pipe(file);
      file.on("finish", () => { file.close(); resolve(); });
    }).on("error", (err) => {
      try { fs.unlinkSync(dest); } catch {}
      reject(err);
    });
  });
}

function followRedirects(url, callback, maxRedirects) {
  maxRedirects = maxRedirects || 5;
  const proto = url.startsWith("https") ? https : require("http");
  return proto.get(url, (res) => {
    if ((res.statusCode === 301 || res.statusCode === 302) && res.headers.location) {
      if (maxRedirects <= 0) {
        callback(res);
        return;
      }
      followRedirects(res.headers.location, callback, maxRedirects - 1);
    } else {
      callback(res);
    }
  });
}
