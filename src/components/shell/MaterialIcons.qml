pragma Singleton
import QtQuick

QtObject {
    readonly property string magnify:             "\uE8B6"  // search
    readonly property string viewDashboard:       "\uE871"  // dashboard
    readonly property string cog:                 "\uE8B8"  // settings
    readonly property string close:               "\uE5CD"  // close
    readonly property string chip:                "\uE30D"  // developer_board
    readonly property string pencil:              "\uE254"  // mode_edit
    readonly property string trashCan:            "\uE872"  // delete
    readonly property string download:            "\uE2C4"  // download
    readonly property string qrCode:              "\uF206"  // qr_code_scanner
    readonly property string link:                "\uE157"  // link
    readonly property string refresh:             "\uE5D5"  // refresh
    readonly property string showChart:           "\uE6E1"  // show_chart
    readonly property string arrowDownward:       "\uE5DB"  // arrow_downward
    readonly property string checkCircle:         "\uE92D"  // check_circle_outline
    readonly property string warning:             "\uE002"  // warning
    readonly property string error:               "\uE000"  // error
    readonly property string info:                "\uE88E"  // info
    readonly property string history:             "\uE889"  // history
    readonly property string chevronLeft:         "\uE5CB"  // chevron_left
    readonly property string chevronRight:        "\uE5CC"  // chevron_right
    readonly property string codeBlocks:          "\uF84D"  // code_blocks
    readonly property string playArrow:           "\uE037"  // play_arrow
    readonly property string stop:                "\uE047"  // stop
    readonly property string restartAlt:          "\uF053"  // restart_alt

    function glyph(name) {
        switch (name) {
        case "magnify":             return magnify
        case "viewDashboard":       return viewDashboard
        case "cog":                 return cog
        case "close":               return close
        case "chip":                return chip
        case "pencil":              return pencil
        case "trashCan":            return trashCan
        case "download":            return download
        case "qrCode":              return qrCode
        case "link":                return link
        case "refresh":             return refresh
        case "showChart":           return showChart
        case "arrowDownward":       return arrowDownward
        case "checkCircle":         return checkCircle
        case "warning":             return warning
        case "error":               return error
        case "info":                return info
        case "history":             return history
        case "chevronLeft":         return chevronLeft
        case "chevronRight":        return chevronRight
        case "codeBlocks":          return codeBlocks
        case "playArrow":           return playArrow
        case "stop":                return stop
        case "restart_alt":         return restartAlt
        default:                    return close
        }
    }
}
