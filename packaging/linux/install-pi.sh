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

# Trả về "status/conclusion runId" của Dev Build cho SHA (dòng đầu),
# hoặc chuỗi rỗng. LƯU Ý: không gọi die trong hàm này vì nó chạy trong $(...).
find_run() {
    gh run list --workflow="$WORKFLOW" --branch=main --limit=20 \
        --json headSha,status,conclusion,databaseId \
        --jq "[.[] | select(.headSha | startswith(\"${SHA}\")) | \"\(.status)/\(.conclusion) \(.databaseId)\"] | .[0] // empty" 2>/dev/null
}

# 1 lần check nhanh, kết quả vào CHECK_STATUS / CHECK_RUNID:
# "NOTFOUND" (chưa có run), "GHERROR" (lỗi gh), hoặc "status/conclusion" + runId.
quick_check() {
    local line
    if ! line="$(find_run)"; then
        CHECK_STATUS="GHERROR"; CHECK_RUNID=""
    elif [[ -z "$line" ]]; then
        CHECK_STATUS="NOTFOUND"; CHECK_RUNID=""
    else
        CHECK_STATUS="${line%% *}"; CHECK_RUNID="${line##* }"
    fi
}

# Đợi build tối đa WAIT_LIMIT. Gọi trực tiếp (KHÔNG trong $(...)).
# Trả về: 0=success (RUN_ID đã set), 1=hết giờ, 2=không thấy run / lỗi gh, 3=build fail.
wait_for_build() {
    local deadline=$((SECONDS + WAIT_LIMIT))
    while (( SECONDS < deadline )); do
        quick_check
        case "$CHECK_STATUS" in
            NOTFOUND|GHERROR) WAIT_MSG="$CHECK_STATUS"; return 2 ;;
            completed/success) RUN_ID="$CHECK_RUNID"; return 0 ;;
            completed/*) WAIT_MSG="$CHECK_STATUS"; return 3 ;;
        esac
        sleep "$POLL_INTERVAL"
    done
    return 1
}

# Đợi tối đa 15 phút; hết giờ thì hỏi user check thủ công từng lần.
RUN_ID=""
quick_check
if [[ "$CHECK_STATUS" == "completed/success" ]]; then
    RUN_ID="$CHECK_RUNID"
elif [[ "$CHECK_STATUS" == "NOTFOUND" ]]; then
    die "không tìm thấy Dev Build cho $SHORT_SHA (CI chưa chạy?)."
elif [[ "$CHECK_STATUS" == "GHERROR" ]]; then
    die "không lấy được trạng thái CI (lỗi gh) — thử lại sau."
else
    info "Dev Build chưa xong ($CHECK_STATUS) — chờ tối đa 15 phút (poll ${POLL_INTERVAL}s)..."
    wait_for_build
    case $? in
        0) : ;; # xong trong 15 phút
        2) die "không lấy được Dev Build cho $SHORT_SHA ($WAIT_MSG)." ;;
        3) die "Dev Build $SHORT_SHA thất bại ($WAIT_MSG) — không cài." ;;
        *)
            # Hết 15 phút: check thủ công lặp lại theo ý user.
            [[ -t 0 ]] || die "hết 15 phút mà build chưa xong — chạy lại script sau (build xong sẽ cài ngay)."
            while true; do
                echo ""
                echo "Hết 15 phút mà Dev Build $SHORT_SHA chưa xong (build mới không cache có thể >1 giờ)."
                read -rp "Nhấn Enter để check nhanh 1 lần, q để thoát: " ans
                [[ "${ans,,}" == "q" ]] && die "dừng theo yêu cầu user."
                quick_check
                case "$CHECK_STATUS" in
                    completed/success) RUN_ID="$CHECK_RUNID"; break ;;
                    completed/*) die "Dev Build $SHORT_SHA thất bại ($CHECK_STATUS) — không cài." ;;
                    NOTFOUND) die "không tìm thấy Dev Build cho $SHORT_SHA." ;;
                    GHERROR) echo "Lỗi gh thoáng qua — Enter để check lại." ;;
                    *) echo "Trạng thái hiện tại: $CHECK_STATUS — chưa xong." ;;
                esac
            done
            ;;
    esac
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
