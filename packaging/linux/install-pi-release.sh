#!/usr/bin/env bash
# Cài bản Release (tag vX.Y.Z, arm64) từ GitHub Releases lên Pi kiosk qua SSH.
#
#   PI_PASSWORD=pi ./packaging/linux/install-pi-release.sh [--tag <tag>] [--host <ip>] [--yes]
#
# Quy trình: lấy .deb của release → scp lên Pi → dpkg -i → verify service + log.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

PI_HOST="${PI_HOST:-100.113.72.90}"
PI_USER="${PI_USER:-pi}"
VERIFY_TIMEOUT=60

TAG=""        # mặc định: release mới nhất
ASSUME_YES=0

usage() {
    cat <<EOF
Usage: PI_PASSWORD=<pass> $0 [--tag <tag>] [--host <ip>] [--yes]

  --tag <tag>   Release cần cài, vd. v2.7.0 (mặc định: release mới nhất).
  --host <ip>   Địa chỉ Pi (mặc định: ${PI_HOST}).
  --yes         Bỏ prompt xác nhận trước khi dpkg -i.
  -h, --help    In help này.

Env:
  PI_PASSWORD   Mật khẩu SSH/sudo của pi@${PI_USER} (bắt buộc).
  PI_HOST       Ghi đè địa chỉ Pi.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)  TAG="${2:-}"; shift 2 ;;
        --host) PI_HOST="${2:-}"; shift 2 ;;
        --yes)  ASSUME_YES=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Không rõ option: $1 (xem --help)." >&2; exit 2 ;;
    esac
done

die() { echo "Lỗi: $*" >&2; exit 1; }
info() { echo "==> $*"; }

[[ -n "${PI_PASSWORD:-}" ]] || die "thiếu PI_PASSWORD (vd. PI_PASSWORD=pi $0)."
command -v gh >/dev/null 2>&1 || die "thiếu lệnh gh (GitHub CLI)."
command -v sshpass >/dev/null 2>&1 || die "thiếu lệnh sshpass."
export SSHPASS="$PI_PASSWORD"

SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=no)

# shellcheck disable=SC1091
source "${ROOT}/packaging/linux/pi-common.sh"

if [[ -z "$TAG" ]]; then
    TAG="$(gh release list --limit 1 --json tagName --jq '.[0].tagName')"
    [[ -n "$TAG" ]] || die "không tìm thấy release nào."
fi
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "tag không hợp lệ: $TAG (cần dạng vX.Y.Z)."
info "Release: $TAG"

TMPDIR_ART="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ART"' EXIT
info "Tải .deb của $TAG..."
gh release download "$TAG" --pattern 'data-logger-app_*_arm64.deb' --dir "$TMPDIR_ART" --clobber
DEB="$(find "$TMPDIR_ART" -name 'data-logger-app_*_arm64.deb' | head -1)"
[[ -n "$DEB" ]] || die "release $TAG không có file .deb arm64."
info "Gói: $(basename "$DEB") ($(du -h "$DEB" | cut -f1))."

if (( ! ASSUME_YES )); then
    read -rp "Cài $(basename "$DEB") ($TAG) lên ${PI_USER}@${PI_HOST}? [y/N]: " ans
    [[ "${ans,,}" == "y" ]] || die "dừng theo yêu cầu user."
fi

deploy_deb_to_pi "$DEB"
verify_pi

echo ""
echo "Hoàn tất: $TAG đã lên ${PI_HOST} và chạy ổn định."
