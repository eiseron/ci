#!/bin/sh
set -eu

template="templates/ansible-collection.yml"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

cat > "$work/ansible-playbook" <<EOF
#!/bin/sh
echo "\$@" >> "$work/calls"
EOF
chmod +x "$work/ansible-playbook"
export PATH="$work:$PATH"

line=$(grep -F 'ansible-playbook --syntax-check' "$template" | sed 's/^[[:space:]]*-[[:space:]]*//')

run() {
  : > "$work/calls"
  echo "$line" | awk -v v="$1" '{gsub(/\$\[\[ inputs\.playbook \]\]/, v); print}' | sh
}

run ""
if [ -s "$work/calls" ]; then
  echo "FAIL: ansible-playbook ran with empty playbook input"
  exit 1
fi

run "playbooks/preview-host.yml"
if ! grep -q -- "--syntax-check playbooks/preview-host.yml" "$work/calls"; then
  echo "FAIL: ansible-playbook not invoked for provided playbook"
  exit 1
fi

echo "PASS: ansible-collection playbook conditional"
