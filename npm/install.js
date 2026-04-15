/**
 * BeamJS postinstall script
 *
 * 1. If a bundled release.tar.gz exists (linux-x64), extract it.
 * 2. Otherwise, download the correct platform binary from GitHub Releases.
 *
 * Supports: linux-x64, darwin-arm64, win32-x64
 */

const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");
const https = require("https");

const packageDir = __dirname;
const packageJson = require(path.join(packageDir, "package.json"));
const version = packageJson.version;
const releaseDir = path.join(packageDir, "release");
const isWindows = process.platform === "win32";
const releaseBin = path.join(releaseDir, "bin", isWindows ? "beamjs.bat" : "beamjs");

// Already installed
if (fs.existsSync(releaseBin)) {
  process.exit(0);
}

// Platform detection
const PLATFORMS = {
  "linux-x64": { artifact: "beamjs-linux-x64.tar.gz", format: "tar" },
  "darwin-arm64": { artifact: "beamjs-darwin-arm64.tar.gz", format: "tar" },
  "win32-x64": { artifact: "beamjs-win32-x64.zip", format: "zip" },
};

const platformKey = `${process.platform}-${process.arch}`;
const platformInfo = PLATFORMS[platformKey];

if (!platformInfo) {
  console.error(`beamjs: unsupported platform: ${platformKey}`);
  console.error(`beamjs: supported platforms: ${Object.keys(PLATFORMS).join(", ")}`);
  process.exit(1);
}

// Try bundled tarball first (linux-x64 is bundled in the npm package)
const bundledTarball = path.join(packageDir, "release.tar.gz");
if (fs.existsSync(bundledTarball) && platformKey === "linux-x64") {
  console.log("beamjs: extracting bundled release...");
  extractArchive(bundledTarball, "tar");
  process.exit(0);
}

// Download from GitHub Releases
const url = `https://github.com/the-einstein/beamjs/releases/download/v${version}/${platformInfo.artifact}`;
const downloadPath = path.join(packageDir, platformInfo.artifact);

console.log(`beamjs: downloading ${platformInfo.artifact} for ${platformKey}...`);

download(url, downloadPath)
  .then(() => {
    console.log("beamjs: extracting release...");
    extractArchive(downloadPath, platformInfo.format);
    // Clean up downloaded archive
    try { fs.unlinkSync(downloadPath); } catch {}
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

function extractArchive(archive, format) {
  try {
    fs.mkdirSync(releaseDir, { recursive: true });

    if (format === "zip") {
      // Windows: use PowerShell to extract zip
      execSync(
        `powershell -Command "Expand-Archive -Path '${archive}' -DestinationPath '${releaseDir}' -Force"`,
        { stdio: "pipe" }
      );
    } else {
      // Unix: use tar
      execSync(`tar xzf "${archive}" -C "${releaseDir}"`, { stdio: "pipe" });
    }

    // Make executables on Unix
    if (!isWindows) {
      const bin = path.join(releaseDir, "bin", "beamjs");
      if (fs.existsSync(bin)) {
        fs.chmodSync(bin, 0o755);
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
        try { fs.unlinkSync(dest); } catch {}
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
