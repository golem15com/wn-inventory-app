git submodule foreach '
  set -e
  for b in develop master main; do
    if git show-ref --verify --quiet "refs/heads/$b"; then
      git checkout -q "$b"
      echo "[$name] checked out existing local branch: $b"
      exit 0
    fi
    if git ls-remote --exit-code --heads origin "$b" >/dev/null 2>&1; then
      git checkout -q -B "$b" "origin/$b"
      echo "[$name] checked out from origin: $b"
      exit 0
    fi
  done
  echo "[$name] no develop/master/main branch found (skipping)"
'
