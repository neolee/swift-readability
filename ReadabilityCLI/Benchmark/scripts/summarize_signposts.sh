#!/usr/bin/env bash
set -euo pipefail

IN="${1:-}"
OUT="${2:-}"

if [[ -z "$IN" || -z "$OUT" ]]; then
  echo "usage: summarize_signposts.sh <input-signposts.xml> <output.md>" >&2
  exit 1
fi

if [[ ! -f "$IN" ]]; then
  echo "missing input file: $IN" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
TMP_OUT="${OUT}.tmp"
rm -f "$TMP_OUT"

{
  echo "# Time Profiler Phase Summary"
  echo
  echo "- Source: \`$IN\`"
  echo "- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  echo "| Phase | Runs | Avg (ms) | Total (ms) |"
  echo "|---|---:|---:|---:|"
  perl -0777 -ne '
my (%nameRef,%etypeRef,%sidRef,%begin,%sum,%count,%nameBySid);
while (/<row>(.*?)<\/row>/sg) {
  my $r=$1;
  my ($time) = $r =~ /<event-time[^>]*>(\d+)<\/event-time>/;
  next unless defined $time;

  my ($etypeTag) = $r =~ /(<event-type\b[^>]*\/?>(?:[^<]*<\/event-type>)?)/;
  my ($etypeId) = ($etypeTag//"") =~ /\bid="([^"]+)"/;
  my ($etypeFmt) = ($etypeTag//"") =~ /\bfmt="([^"]+)"/;
  my ($etypeRefId) = ($etypeTag//"") =~ /\bref="([^"]+)"/;
  $etypeRef{$etypeId} = $etypeFmt if defined $etypeId && defined $etypeFmt;
  my $etype = defined $etypeFmt ? $etypeFmt : (defined $etypeRefId ? ($etypeRef{$etypeRefId}//"") : "");

  my ($sidTag) = $r =~ /(<os-signpost-identifier\b[^>]*\/?>(?:[^<]*<\/os-signpost-identifier>)?)/;
  next unless defined $sidTag;
  my ($sidId) = $sidTag =~ /\bid="([^"]+)"/;
  my ($sidRefId) = $sidTag =~ /\bref="([^"]+)"/;
  my ($sidVal) = $sidTag =~ />(\d+)</;
  $sidRef{$sidId} = $sidVal if defined $sidId && defined $sidVal;
  my $sid = defined $sidVal ? $sidVal : (defined $sidRefId ? ($sidRef{$sidRefId}//"") : "");
  next if $sid eq "";

  my ($nameTag) = $r =~ /(<signpost-name\b[^>]*\/?>(?:[^<]*<\/signpost-name>)?)/;
  my ($nameId) = ($nameTag//"") =~ /\bid="([^"]+)"/;
  my ($nameFmt) = ($nameTag//"") =~ /\bfmt="([^"]+)"/;
  my ($nameRefId) = ($nameTag//"") =~ /\bref="([^"]+)"/;
  $nameRef{$nameId} = $nameFmt if defined $nameId && defined $nameFmt;
  my $name = defined $nameFmt ? $nameFmt : (defined $nameRefId ? ($nameRef{$nameRefId}//"") : "");

  if ($etype eq "Begin") {
    $begin{$sid} = $time;
    $nameBySid{$sid} = $name if $name ne "";
  } elsif ($etype eq "End") {
    next unless exists $begin{$sid};
    my $dur = $time - $begin{$sid};
    my $n = $name ne "" ? $name : ($nameBySid{$sid}//"unknown");
    $sum{$n} += $dur;
    $count{$n}++;
    delete $begin{$sid};
  }
}
for my $n (sort { ($sum{$b}/($count{$b}||1)) <=> ($sum{$a}/($count{$a}||1)) } keys %sum) {
  printf "| %s | %d | %.3f | %.3f |\n", $n, $count{$n}, ($sum{$n}/($count{$n}||1))/1_000_000, $sum{$n}/1_000_000;
}
' "$IN"
} > "$TMP_OUT"

table_lines=$(rg -c '^\| ' "$TMP_OUT" || true)
if [[ "$table_lines" -le 2 ]]; then
  echo "no phase rows were parsed from signpost xml: $IN" >&2
  rm -f "$TMP_OUT"
  exit 2
fi

mv "$TMP_OUT" "$OUT"

echo "phase summary report: $OUT"
