#!/usr/bin/env bash
# Cài bản Dev Build (arm64) lên Pi kiosk qua SSH.
#
#   PI_PASSWORD=pi ./packaging/linux/install-pi.sh [--sha <sha>] [--host <ip>] [--yes]
#
# Quy trình: tìm Dev Build của commit → tải .deb → scp lên Pi → dpkg -i →
# verify service + log. Cần `gh` đã login và SSHPASS=PI_PASSWORD.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "${ROOT}"

PI_HOST="${PI_HOST:-100.113.72.90}"
PI_USER="${PI_USER:-pi}"
WORKFLOW="dev-build.yml"
POLL_INTERVAL=30
WAIT_LIMIT=900   # 15 phút: build cache ~3-4 phút; build mới không cache >1 giờ
VERIFY_TIMEOUT=60

SHA=""
ASSUME_YES=0

usage() {
    cat <<EOF
Usage: PI_PASSWORD=<pass> $0 [--sha <sha>] [--host <ip>] [--yes]

  --sha <sha>   Commit cần cài (mặc định: HEAD local, phải đã push).
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
        --sha)  SHA="${2:-}"; shift 2 ;;
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

if [[ -z "$SHA" ]]; then
    SHA="$(git rev-parse HEAD)"
fi
SHORT_SHA="${SHA:0:7}"
info "Commit: $SHA"

# Commit phải có trên origin/main để CI từng build nó.
if ! git merge-base --is-ancestor "$SHA" origin/main 2>/dev/null; then
    die "commit $SHORT_SHA chưa có trên origin/main — push trước rồi cài."
fi

SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=no)

# shellcheck disable=SC1091
source "${ROOT}/packaging/linux/pi-common.sh"

# Trả về "status/conclusion/runId" của Dev Build cho SHA, hoặc chuỗi rỗng.
find_run() {
    gh run list --workflow="$WORKFLOW" --branch=main --limit=20 \
        --json headSha,status,conclusion,databaseId \
        --jq ".[] | select(.headSha | startswith(\"${SHA}\")) | \"\(.status)/\(.conclusion) \(.databaseId)\"" 2>/dev/null | head -1
}

# 1 lần check nhanh: in trạng thái, trả về runId nếu completed/success.
quick_check() {
    local line run_status run_id
    line="$(find_run)"
    [[ -n "$line" ]] || { echo "NOTFOUND"; return 0; }
    run_status="${line%% *}"
    run_id="${line##* }"
    echo "$run_status $run_id"
}

wait_for_build() {
    local deadline=$((SECONDS + WAIT_LIMIT)) res status run_id
    while (( SECONDS < deadline )); do
        res="$(quick_check)"
        if [[ "$res" == "NOTFOUND" ]]; then
            die "không tìm thấy Dev Build cho $SHORT_SHA (CI chưa chạy?)."
        fi
        status="${res% *}"; run_id="${res#* }"
        case "$status" in
            completed/success) echo "$run_id"; return 0 ;;
            completed/*) die "Dev Build $SHORT_SHA thất bại ($status) — không cài." ;;
        esac
        sleep "$POLL_INTERVAL"
    done
    return 1
}

# Đợi tối đa 15 phút; hết giờ thì hỏi user check thủ công từng lần.
RUN_ID=""
if res_line="$(quick_check)" && [[ "$res_line" != "NOTFOUND" ]] \
    && [[ "${res_line% *}" == "completed/success" ]]; then
    RUN_ID="${res_line#* }"
else
    info "Dev Build chưa xong — chờ tối đa 15 phút (poll ${POLL_INTERVAL}s)..."
    if RUN_ID="$(wait_for_build)"; then
        : # xong trong 15 phút
    else
        # Hết 15 phút: check thủ công lặp lại theo ý user.
        while true; do
            echo ""
            echo "Hết 15 phút mà Dev Build $SHORT_SHA chưa xong (build mới không cache có thể >1 giờ)."
            read -rp "Nhấn Enter để check nhanh 1 lần, q để thoát: " ans
            [[ "${ans,,}" == "q" ]] && die "dừng theo yêu cầu user."
            res_line="$(quick_check)"
            [[ "$res_line" == "NOTFOUND" ]] && die "không tìm thấy Dev Build cho $SHORT_SHA."
            status="${res_line% *}"; RUN_ID="${res_line#* }"
            case "$status" in
                completed/success) break ;;
                completed/*) die "Dev Build $SHORT_SHA thất bại ($status) — không cài." ;;
                *) echo "Trạng thái hiện tại: $status — chưa xong." ;;
            esac
        done
    fi
fi
info "Dev Build success, run $RUN_ID."

# Cảnh báo nếu CI đỏ (dù Dev Build xanh vẫn cài được nhưng nên biết).
CI_STATUS="$(gh run list --workflow=ci.yml --branch=main --limit=20 \
    --json headSha,status,conclusion \
    --jq ".[] | select(.headSha | startswith(\"${SHA}\")) | \"\(.status)/\(.conclusion)\"" 2>/dev/null | head -1)"
if [[ -n "$CI_STATUS" && "$CI_STATUS" != "completed/success" ]]; then
    echo "Cảnh báo: CI của $SHORT_SHA đang ở trạng thái $CI_STATUS."
    if (( ! ASSUME_YES )); then
        read -rp "Vẫn cài tiếp? [y/N]: " ans
        [[ "${ans,,}" == "y" ]] || die "dừng theo yêu cầu user."
    fi
fi

TMPDIR_ART="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ART"' EXIT
info "Tải artifact run $RUN_ID..."
gh run download "$RUN_ID" --dir "$TMPDIR_ART" >/dev/null
DEB="$(find "$TMPDIR_ART" -name 'data-logger-app_*_arm64.deb' | head -1)"
[[ -n "$DEB" ]] || die "không thấy file .deb trong artifact."
info "Gói: $(basename "$DEB") ($(du -h "$DEB" | cut -f1))."

if (( ! ASSUME_YES )); then
    read -rp "Cài $(basename "$DEB") lên ${PI_USER}@${PI_HOST}? [y/N]: " ans
    [[ "${ans,,}" == "y" ]] || die "dừng theo yêu cầu user."
fi

deploy_deb_to_pi "$DEB"
verify_pi

echo ""
echo "Hoàn tất: ${SHORT_SHA} đã lên ${PI_HOST} và chạy ổn định."
