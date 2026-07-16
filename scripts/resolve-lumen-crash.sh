#!/usr/bin/env bash
set -euo pipefail

# Resolve the latest Project Lumen main auto-release for lumen-crash and
# stage GitHub Release assets into android/local-maven so Gradle can resolve
# without hard-pinning a version and without requiring cross-repo Packages auth.
#
# Usage:
#   scripts/resolve-lumen-crash.sh
# Optional env:
#   GH_TOKEN / GITHUB_TOKEN  auth for API rate limits / private assets

OWNER_REPO="${LUMEN_CRASH_OWNER_REPO:-Chloemlla/Project-Lumen}"
API="https://api.github.com/repos/${OWNER_REPO}/releases?per_page=100"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="${ROOT_DIR}/android"
LOCAL_MAVEN="${ANDROID_DIR}/local-maven"
VERSION_FILE="${ANDROID_DIR}/lumen-crash.version"
GRADLE_PROPS="${ANDROID_DIR}/gradle.properties"
RELEASE_JSON_FILE="$(mktemp)"
STAGE="$(mktemp -d)"
trap 'rm -f "${RELEASE_JSON_FILE}"; rm -rf "${STAGE}"' EXIT

AUTH_HEADER=()
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -n "${TOKEN}" ]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${TOKEN}")
fi

echo "Resolving latest lumen-crash-v* release from ${OWNER_REPO}..."
curl -fsSL "${AUTH_HEADER[@]}" \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: nexai-lumen-crash-resolver" \
  "$API" > "${RELEASE_JSON_FILE}"

VERSION="$(
  python - "${RELEASE_JSON_FILE}" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    releases = json.load(f)
candidates = [
    r for r in releases
    if not r.get("draft") and str(r.get("tag_name", "")).startswith("lumen-crash-v")
]
if not candidates:
    raise SystemExit("No lumen-crash release found")
candidates.sort(key=lambda r: r.get("published_at") or r.get("created_at") or "")
latest = candidates[-1]
print(str(latest["tag_name"])[len("lumen-crash-v"):])
PY
)"

if [ -z "${VERSION}" ] || [ "${VERSION}" = "null" ]; then
  echo "No lumen-crash release found" >&2
  exit 1
fi

echo "Resolved latest lumen-crash main auto release: ${VERSION}"
printf '%s\n' "${VERSION}" > "${VERSION_FILE}"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "LUMEN_CRASH_VERSION=${VERSION}" >> "${GITHUB_ENV}"
fi

if [ -f "${GRADLE_PROPS}" ]; then
  tmp="$(mktemp)"
  grep -v '^lumenCrashVersion=' "${GRADLE_PROPS}" > "${tmp}" || true
  mv "${tmp}" "${GRADLE_PROPS}"
  if [ -s "${GRADLE_PROPS}" ] && [ -n "$(tail -c1 "${GRADLE_PROPS}" 2>/dev/null || true)" ]; then
    echo "" >> "${GRADLE_PROPS}"
  fi
  echo "lumenCrashVersion=${VERSION}" >> "${GRADLE_PROPS}"
else
  printf 'lumenCrashVersion=%s\n' "${VERSION}" > "${GRADLE_PROPS}"
fi

download_asset() {
  local name="$1"
  local out="$2"
  local required="${3:-1}"
  local url
  url="$(
    python - "${RELEASE_JSON_FILE}" "${VERSION}" "${name}" <<'PY'
import json, sys
path, version, name = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, encoding="utf-8") as f:
    releases = json.load(f)
tag = f"lumen-crash-v{version}"
for r in releases:
    if r.get("tag_name") == tag:
        for a in r.get("assets", []):
            if a.get("name") == name:
                print(a.get("browser_download_url") or "")
                raise SystemExit(0)
raise SystemExit(1)
PY
  )" || true
  if [ -z "${url}" ]; then
    if [ "${required}" = "1" ]; then
      echo "Missing release asset URL for ${name}" >&2
      return 1
    fi
    echo "Optional asset not found: ${name}"
    return 0
  fi
  echo "Downloading ${name}..."
  curl -fsSL "${AUTH_HEADER[@]}" -L -o "${out}" "${url}"
}

stage_maven_artifact() {
  local artifact_id="$1"
  local aar="${STAGE}/${artifact_id}-${VERSION}.aar"
  local pom="${STAGE}/${artifact_id}-${VERSION}.pom"
  local module="${STAGE}/${artifact_id}-${VERSION}.module"
  local dest="${LOCAL_MAVEN}/com/chloemlla/lumen/${artifact_id}/${VERSION}"

  if [ ! -f "${aar}" ]; then
    echo "Failed to stage ${artifact_id}: missing AAR" >&2
    return 1
  fi

  rm -rf "${dest}"
  mkdir -p "${dest}"
  cp "${aar}" "${dest}/"
  if [ -f "${pom}" ]; then
    cp "${pom}" "${dest}/"
  else
    cat > "${dest}/${artifact_id}-${VERSION}.pom" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd"
  xmlns="http://maven.apache.org/POM/4.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.chloemlla.lumen</groupId>
  <artifactId>${artifact_id}</artifactId>
  <version>${VERSION}</version>
  <packaging>aar</packaging>
  <name>${artifact_id}</name>
</project>
EOF
  fi
  if [ -f "${module}" ]; then
    cp "${module}" "${dest}/"
  fi
  echo "Staged ${artifact_id}:${VERSION} -> ${dest}"
}

echo "Staging lumen-crash ${VERSION} into local Maven repo..."
download_asset "lumen-crash-${VERSION}.aar" "${STAGE}/lumen-crash-${VERSION}.aar" 1
download_asset "lumen-crash-${VERSION}.pom" "${STAGE}/lumen-crash-${VERSION}.pom" 0
download_asset "lumen-crash-${VERSION}.module" "${STAGE}/lumen-crash-${VERSION}.module" 0
download_asset "lumen-crash-core-${VERSION}.aar" "${STAGE}/lumen-crash-core-${VERSION}.aar" 1
download_asset "lumen-crash-core-${VERSION}.pom" "${STAGE}/lumen-crash-core-${VERSION}.pom" 0
download_asset "lumen-crash-core-${VERSION}.module" "${STAGE}/lumen-crash-core-${VERSION}.module" 0
download_asset "checksums.txt" "${STAGE}/checksums.txt" 0

if [ -f "${STAGE}/checksums.txt" ] && command -v sha256sum >/dev/null 2>&1; then
  (
    cd "${STAGE}"
    sha256sum -c checksums.txt --ignore-missing || true
  )
fi

stage_maven_artifact "lumen-crash-core"
stage_maven_artifact "lumen-crash"

# Ensure published lumen-crash POM dependency on lumen-crash-core can resolve offline.
# If the release POM was missing, inject an explicit dependency block.
BUNDLE_POM="${LOCAL_MAVEN}/com/chloemlla/lumen/lumen-crash/${VERSION}/lumen-crash-${VERSION}.pom"
if [ -f "${BUNDLE_POM}" ] && ! grep -q 'lumen-crash-core' "${BUNDLE_POM}"; then
  python - "${BUNDLE_POM}" "${VERSION}" <<'PY'
from pathlib import Path
import sys
pom_path = Path(sys.argv[1])
version = sys.argv[2]
text = pom_path.read_text(encoding="utf-8")
dep = f"""
  <dependencies>
    <dependency>
      <groupId>com.chloemlla.lumen</groupId>
      <artifactId>lumen-crash-core</artifactId>
      <version>{version}</version>
      <scope>compile</scope>
    </dependency>
  </dependencies>
"""
if "</project>" not in text:
    raise SystemExit(f"Invalid POM: {pom_path}")
if "<dependencies>" in text:
    raise SystemExit(0)
pom_path.write_text(text.replace("</project>", dep + "</project>"), encoding="utf-8")
print(f"Injected lumen-crash-core dependency into {pom_path}")
PY
fi

echo "Local Maven repo ready at ${LOCAL_MAVEN}"
echo "implementation(\"com.chloemlla.lumen:lumen-crash:${VERSION}\")"
echo "Release page: https://github.com/${OWNER_REPO}/releases/tag/lumen-crash-v${VERSION}"