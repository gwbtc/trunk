#!/usr/bin/env bash
# offline-tests.sh: run the Hoon suites in tests/lib through vere eval,
# with no ship (scripts/hoon-test-kit/offline-test.py), several at once.
# The libs under test are pure, and three suites wrap the desk's own
# gen/test-*.hoon checks. The ship run (TESTING.md) stays the verdict.
#
#   scripts/offline-tests.sh                        every suite
#   scripts/offline-tests.sh trunk-guest ...        by name, no .hoon
#   JOBS=4 scripts/offline-tests.sh                 at most 4 at a time
set -uo pipefail
cd "$(dirname "$0")/.."
if (($#)); then names=("$@"); else
  names=(); for f in tests/lib/*.hoon; do names+=("$(basename "$f" .hoon)"); done
fi
jobs=${JOBS:-$(nproc)}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
run() {
  python3 scripts/hoon-test-kit/offline-test.py "tests/lib/$1.hoon" > "$tmp/$1" 2>&1
  echo $? > "$tmp/$1.rc"
}
for n in "${names[@]}"; do
  while (($(jobs -rp | wc -l) >= jobs)); do wait -n; done
  run "$n" &
done
wait
fail=0 pass=0 total=0
for n in "${names[@]}"; do
  last=$(tail -1 "$tmp/$n")
  printf '%-34s %s\n' "$n" "$last"
  if [[ "$(cat "$tmp/$n.rc")" == 0 ]] && [[ $last =~ ^([0-9]+)\ passed,\ ([0-9]+)\ failed ]]; then
    pass=$((pass + BASH_REMATCH[1])); total=$((total + BASH_REMATCH[1] + BASH_REMATCH[2]))
  else fail=1; sed -n '1,40p' "$tmp/$n"; fi
done
echo "offline: $pass passed of $total, ${#names[@]} suites"
exit $fail
