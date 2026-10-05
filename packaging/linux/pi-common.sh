#!/usr/bin/env bash
# Hàm dùng chung cho các script cài .deb lên Pi kiosk (dev build / release).
# Được source bởi install-pi.sh và install-pi-release.sh — không chạy trực tiếp.
#
# Yêu cầu trước khi source: PI_HOST, PI_USER, PI_PASSWORD, VERIFY_TIMEOUT,
# ASSUME_YES, SSH_OPTS (mảng), hàm die/info đã định nghĩa.

pi_ssh() { sshpass -e ssh "${SSH_OPTS[@]}" "${PI_USER}@${PI_HOST}" "$@"; }
pi_scp() { sshpass -e scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$1" "${PI_USER}@${PI_HOST}:/tmp/"; }

# Chép $1 (file .deb local) lên Pi, dpkg -i, so md5 trước/sau.
# In ra tên file .deb đã cài (để caller dùng tiếp nếu cần).
deploy_deb_to_pi() {
    local deb="$1"
    local deb_name
    deb_name="$(basename "$deb")"

    info "Chép lên Pi..."
    pi_scp "$deb" || die "scp thất bại — kiểm tra Pi có online và PI_PASSWORD đúng không."

    info "Cài đặt (dpkg -i)..."
    local md5_before md5_after
    md5_before="$(pi_ssh 'md5sum /usr/bin/DataLogger' 2>/dev/null | cut -d' ' -f1 || true)"
    pi_ssh "echo '$PI_PASSWORD' | sudo -S dpkg -i /tmp/${deb_name}" | tail -3
    md5_after="$(pi_ssh 'md5sum /usr/bin/DataLogger' | cut -d' ' -f1)"
    if [[ -n "$md5_before" && "$md5_before" == "$md5_after" ]]; then
        echo "Cảnh báo: md5 binary không đổi sau khi cài ($md5_after) — có thể gói trùng phiên bản đã cài."
        if (( ! ASSUME_YES )); then
            read -rp "Vẫn coi như thành công và verify tiếp? [y/N]: " ans
            [[ "${ans,,}" == "y" ]] || die "dừng theo yêu cầu user."
        fi
    else
        info "Binary mới: $md5_after."
    fi
}

# Verify full sau cài: service active + đợi Polling started + quét lỗi.
verify_pi() {
    info "Verify service..."
    local active badlog polled="" deadline=$((SECONDS + VERIFY_TIMEOUT))
    active="$(pi_ssh 'systemctl is-active datalogger.service')"
    [[ "$active" == "active" ]] || die "service không active (đang: $active)."
    while (( SECONDS < deadline )); do
        if pi_ssh 'journalctl -u datalogger.service --since "5 min ago" --no-pager' \
            2>/dev/null | grep -q "Polling started"; then
            polled=1
            break
        fi
        sleep 5
    done
    [[ -n "$polled" ]] || {
        # Pi mới chưa cấu hình sensor thì app không poll (đúng thiết kế:
        # MonitorController báo "No active sensors" và return). Miễn service
        # process còn sống và log sạch thì vẫn coi như cài thành công.
        if pi_ssh 'pgrep -x DataLogger >/dev/null'; then
            echo "Chú ý: quá ${VERIFY_TIMEOUT}s chưa thấy 'Polling started' —"
            echo "có thể Pi chưa cấu hình sensor (mở Settings trên kiosk để thêm)."
        else
            die "quá ${VERIFY_TIMEOUT}s chưa thấy 'Polling started' và process đã chết — kiểm tra log trên Pi."
        fi
    }

    badlog="$(pi_ssh 'journalctl -u datalogger.service --since "5 min ago" --no-pager' 2>/dev/null \
        | grep -E "SEGV|TypeError|NOT NULL|SensorDao::save error" | head -5 || true)"
    if [[ -n "$badlog" ]]; then
        echo "Phát hiện lỗi sau update:"
        echo "$badlog"
        die "verify thất bại — xem log đầy đủ trên Pi."
    fi
}
