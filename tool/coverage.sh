#!/usr/bin/env bash
#
# Prints the coverage of the last test run, the way CI measures it.
#
#   very_good test --coverage    # writes coverage/lcov.info
#   tool/coverage.sh             # says what it came to
#
# very_good.yaml already holds the exclusion list and the 100% floor, so a
# local run fails exactly where CI would — but it only prints a percentage
# when coverage is short. This answers the other question: what is the number
# when everything passes, and which files hold the gaps.
#
# The exclusion globs are read from very_good.yaml rather than kept here, so
# there is one list to keep honest.
set -euo pipefail

cd "$(dirname "$0")/.."

lcov_file=coverage/lcov.info
config_file=very_good.yaml
min_coverage=${MIN_COVERAGE:-100}

if [ ! -f "$lcov_file" ]; then
  echo "error: $lcov_file not found; run the suite with coverage first." >&2
  exit 1
fi

globs=$(sed -n 's/^[[:space:]]*exclude_coverage:[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$config_file")
if [ -z "$globs" ]; then
  echo "error: no exclude_coverage line found in $config_file." >&2
  exit 1
fi

# A report older than the newest source file is measuring code that no longer
# exists, which is the one way this output could quietly lie.
if [ -n "$(find lib test -name '*.dart' -newer "$lcov_file" -print -quit)" ]; then
  echo "warning: $lcov_file is older than some sources; re-run the suite." >&2
fi

awk -v globs="$globs" -v min="$min_coverage" '
  # Translates one glob into an anchored regular expression. "**/" spans any
  # number of directories or none, "**" spans anything at all, and a lone "*"
  # stops at a path separator.
  function glob_to_regex(glob,   re) {
    re = glob
    gsub(/\./, "\\.", re)
    gsub(/\*\*\//, "@@ANYDIRS@@", re)
    gsub(/\*\*/, "@@ANY@@", re)
    gsub(/\*/, "[^/]*", re)
    gsub(/@@ANYDIRS@@/, "(.*/)?", re)
    gsub(/@@ANY@@/, ".*", re)
    return "^" re "$"
  }

  BEGIN {
    count = split(globs, patterns_raw, " ")
    for (i = 1; i <= count; i++) {
      if (patterns_raw[i] != "") {
        patterns[++pattern_count] = glob_to_regex(patterns_raw[i])
      }
    }
  }

  /^SF:/ {
    file = substr($0, 4)
    skipping = 0
    for (i = 1; i <= pattern_count; i++) {
      if (file ~ patterns[i]) { skipping = 1; excluded_files++; break }
    }
    if (!skipping) counted_files++
    next
  }

  /^DA:/ {
    if (skipping) next
    split(substr($0, 4), field, ",")
    total++
    if (field[2] + 0 > 0) hit++
    else missing[file] = missing[file] " " field[1]
  }

  END {
    for (file in missing) printf "uncovered  %s:%s\n", file, missing[file]
    if (total == 0) {
      print "error: nothing left to measure" > "/dev/stderr"
      exit 1
    }
    pct = 100 * hit / total
    printf "\n%d of %d lines covered (%.2f%%) in %d files, %d excluded\n", \
      hit, total, pct, counted_files, excluded_files
    if (pct + 0.0001 < min) {
      printf "below the %s%% floor\n", min
      exit 1
    }
  }
' "$lcov_file"
