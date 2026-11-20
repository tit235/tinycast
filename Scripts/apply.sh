#!/bin/bash
# Applies every patch in .patches onto a pristine upstream checkout, in name order.
# --3way falls back to a merge when the context drifted, so only a real conflict fails.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
for patch in .patches/*.patch; do
  echo "applying ${patch##*/}"
  git apply --3way --whitespace=nowarn "$patch"
done

# A patch to the extension runtime's sources only counts once the committed bundle is rebuilt from
# them. Upstream's build is deterministic, so an unpatched runtime would regenerate byte-identical.
if ! git diff --quiet HEAD -- Scripts/raycast-runtime/src; then
  echo "rebuilding the extension runtime bundle"
  (cd Scripts/raycast-runtime && npx --yes pnpm@10 install --frozen-lockfile --silent && node build.mjs)
fi

# Regenerate unconditionally: additions and tracked source renames both change project membership.
command -v xcodegen >/dev/null || brew install --quiet xcodegen
echo "regenerating the Xcode project from project.yml"
xcodegen generate --quiet

# Patch 0023's theme core is read by Theme.swift, which several harnesses compile on their own, so
# list it beside Theme.swift wherever it appears. A rewrite: a harness upstream adds later is covered.
if [ -f Tinycast/Features/Settings/RaycastThemeCore.swift ]; then
  sed -i.bak 's#Tinycast/DesignSystem/Theme\.swift#& Tinycast/Features/Settings/RaycastThemeCore.swift#g' \
    Scripts/run-tests.sh
  rm -f Scripts/run-tests.sh.bak
fi

# Patch 0023 redraws themed colors through observation, which needs each ramp token computed on read
# rather than stored once: `static let x = ramp(…)` becomes `static var x: Color { ramp(…) }`. A
# rewrite, so upstream retuning or adding a token never conflicts with a hunk.
if [ -f Tinycast/Features/Settings/RaycastThemeCore.swift ]; then
  sed -E -i.bak 's/^( +)static let ([A-Za-z0-9_]+) = ramp\((.*)\)$/\1static var \2: Color { ramp(\3) }/' \
    Tinycast/DesignSystem/Theme.swift
  rm -f Tinycast/DesignSystem/Theme.swift.bak
fi
