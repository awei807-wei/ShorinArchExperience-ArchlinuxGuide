import QtQuick

Item {
    id: cell

    required property string metricLabel
    required property string metricValue
    required property color labelColor
    required property color valueColor
    required property string monoFont
    required property real labelSlotWidth
    required property real valueSlotWidth
    required property real labelValueGap
    required property int labelFontSize
    required property int valueFontSize
    required property real labelLetterSpacing

    Item {
        id: content

        width: cell.labelSlotWidth + cell.labelValueGap + cell.valueSlotWidth
        height: Math.max(labelText.implicitHeight, valueText.implicitHeight)
        anchors.centerIn: parent

        Text {
            id: labelText

            anchors.left: parent.left
            anchors.baseline: valueText.baseline
            width: cell.labelSlotWidth
            text: cell.metricLabel
            textFormat: Text.PlainText
            color: cell.labelColor
            font.family: cell.monoFont
            font.pixelSize: cell.labelFontSize
            font.weight: Font.DemiBold
            font.letterSpacing: cell.labelLetterSpacing
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.NativeRendering
        }

        Text {
            id: valueText

            anchors.left: labelText.right
            anchors.leftMargin: cell.labelValueGap
            anchors.verticalCenter: parent.verticalCenter
            width: cell.valueSlotWidth
            text: cell.metricValue
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignRight
            color: cell.valueColor
            font.family: cell.monoFont
            font.pixelSize: cell.valueFontSize
            font.weight: Font.Bold
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.NativeRendering
        }
    }
}
