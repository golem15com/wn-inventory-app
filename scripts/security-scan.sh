#!/bin/bash
# scripts/security-scan.sh
# Quick pattern scan for common PHP vulnerabilities
# Usage: bash scripts/security-scan.sh plugins/golem15 plugins/winter
set -e
cd "$(dirname "$0")/.."

TARGETS="${@:-plugins/golem15 plugins/winter}"

echo "=== Dangerous Functions ==="
rg -n 'eval\s*\(' $TARGETS --glob '*.php' || true
rg -n '\bexec\s*\(' $TARGETS --glob '*.php' || true
rg -n '\bsystem\s*\(' $TARGETS --glob '*.php' || true
rg -n 'shell_exec\s*\(' $TARGETS --glob '*.php' || true
rg -n 'passthru\s*\(' $TARGETS --glob '*.php' || true
rg -n 'proc_open\s*\(' $TARGETS --glob '*.php' || true
rg -n 'popen\s*\(' $TARGETS --glob '*.php' || true

echo ""
echo "=== Unsafe Deserialization ==="
rg -n 'unserialize\s*\(' $TARGETS --glob '*.php' || true

echo ""
echo "=== Raw SQL / SQL Injection Vectors ==="
rg -n 'DB::raw\s*\(' $TARGETS --glob '*.php' || true
rg -n -e '->whereRaw\s*\(' --glob '*.php' $TARGETS || true
rg -n -e '->selectRaw\s*\(' --glob '*.php' $TARGETS || true
rg -n -e '->orderByRaw\s*\(' --glob '*.php' $TARGETS || true
rg -n -e '->havingRaw\s*\(' --glob '*.php' $TARGETS || true
rg -n -e '->groupByRaw\s*\(' --glob '*.php' $TARGETS || true

echo ""
echo "=== Direct Superglobal Access (bypassing Laravel Request) ==="
rg -n '\$_GET\[' $TARGETS --glob '*.php' || true
rg -n '\$_POST\[' $TARGETS --glob '*.php' || true
rg -n '\$_REQUEST\[' $TARGETS --glob '*.php' || true
rg -n '\$_COOKIE\[' $TARGETS --glob '*.php' || true
rg -n '\$_SERVER\[' $TARGETS --glob '*.php' || true
rg -n '\$_FILES\[' $TARGETS --glob '*.php' || true

echo ""
echo "=== Mass Assignment Risk ==="
rg -n '\$guarded\s*=\s*\[\s*\]' $TARGETS --glob '*.php' || true
rg -n '\$fillable\s*=\s*\[' $TARGETS --glob '*.php' || true

echo ""
echo "=== Unescaped Output (Twig) ==="
rg -n '\|raw' $TARGETS --glob '*.htm' || true

echo ""
echo "=== Hardcoded Secrets ==="
rg -ni 'password\s*=\s*["\x27][^"\x27]+["\x27]' $TARGETS --glob '*.php' || true
rg -ni 'api_key\s*=\s*["\x27][^"\x27]+["\x27]' $TARGETS --glob '*.php' || true
rg -ni 'secret\s*=\s*["\x27][^"\x27]+["\x27]' $TARGETS --glob '*.php' || true

echo ""
echo "=== File Operations with User Input ==="
rg -n 'file_get_contents\s*\(' $TARGETS --glob '*.php' || true
rg -n 'file_put_contents\s*\(' $TARGETS --glob '*.php' || true
rg -n 'fopen\s*\(' $TARGETS --glob '*.php' || true
rg -n '\binclude\s*\$' $TARGETS --glob '*.php' || true
rg -n '\brequire\s*\$' $TARGETS --glob '*.php' || true

echo ""
echo "=== Weak Cryptography ==="
rg -n '\bmd5\s*\(' $TARGETS --glob '*.php' || true
rg -n '\bsha1\s*\(' $TARGETS --glob '*.php' || true
rg -n '\brand\s*\(' $TARGETS --glob '*.php' || true
rg -n '\bmt_rand\s*\(' $TARGETS --glob '*.php' || true

echo ""
echo "=== Done ==="
