import QtQuick
import QtQuick.VirtualKeyboard

// On-screen keyboard for touch input.
//
// In fullScreenMode the InputPanel grows to fill the entire window (Qt VKB
// manages the height automatically). We must NOT constrain height — only set
// width and drive y from the `active` flag:
//   • inactive  → y = parent.height   (off-screen below)
//   • active    → y = parent.height - height
//       - fullScreenMode off: height ≈ keyboard height  → slides up from bottom
//       - fullScreenMode on:  height = parent.height    → y snaps to 0, fills screen
InputPanel {
    id: inputPanel
    z: 999
    width: parent.width
    y: active ? parent.height - height : parent.height
}
