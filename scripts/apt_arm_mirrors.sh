#!/bin/bash

MIRRORLIST="http://mirrors.ubuntu.com/"
SAMPLES=3
BYTES=511999
TIMEOUT=1 # seconds, can be float
TESTFILE="dists/focal/main/binary-arm64/Packages.gz"
_listOfUrls=()
declare -A _uniqueUrls # need declare for associative arrays

function findCountryFiles() {
  curl -s "$1" | grep -Po '(?<=<a href=")([A-Z]{2}\.txt)(?=")'
}

mapfile -t _listOfUrls < <(
  for country in $(findCountryFiles "$MIRRORLIST"); do
    curl -s "${MIRRORLIST}/$country" | grep 'ubuntu-ports' &
  done
)

function benchmark() {
  curl -r 0-"$BYTES" --max-time "$TIMEOUT" --silent --output /dev/null --write-out '%{time_total}' "${1}${TESTFILE}"
}

# Modified from https://gist.github.com/lox/9152137
function test_mirror() {
  for _ in $(seq 1 "$SAMPLES") ; do
    time=$(benchmark "$1")
    if [ "$time" == "0.000" ] ; then exit 1; fi
    echo "$time"
  done
}

# calculates the mean of all arguments
function mean() {
  len=$#
  echo "$@" | tr " " "\n" | sort -n | head -n $(((len+1)/2)) | tail -n 1
}

# Create a unique array
for i in "${_listOfUrls[@]}"; do
  _uniqueUrls[$i]=1
done

# ${!_uniqueUrls[@]} syntax means that we're only reading the keys in
# the associative array. Needs Bash >= 4
for u in "${!_uniqueUrls[@]}"; do
  result=$(mean "$(test_mirror "$u")")
  if [ "$result" != "-nan" ] ; then
    printf '%-60s %.5f\n' "$u" "$result"
  else
    printf '%-60s failed, ignoring\n' "$u" 1>&2
  fi
done | sort -n -k 2 | grep http
