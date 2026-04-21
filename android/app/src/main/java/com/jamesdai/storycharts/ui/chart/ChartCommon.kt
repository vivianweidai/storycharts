package com.jamesdai.storycharts.ui.chart

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope

val PlotColors = listOf(
    Color(0xFF4A80D4),
    Color(0xFFE06140),
    Color(0xFF4FA140),
    Color(0xFFD4A121),
    Color(0xFF8F61BF),
    Color(0xFF289E8E),
    Color(0xFFE0709A),
    Color(0xFF8A6640),
    Color(0xFF4F4FB0),
    Color(0xFFE08050),
)

val GridColor = Color(0xFFD9E6F2)
val ChartBg = Color(0xFFF7FAFF)
val ChartStroke = Color(0xFF8CB3BF)
val MidlineColor = Color(0xFF808080).copy(alpha = 0.5f)

const val INSET = 0.05f
const val GRID_COUNT = 20

// Explicit colors (>= 0) win in order; conflicts and unassigned plots get
// reassigned to the next free color so no two plots share a color.
fun resolveColorIndices(colors: List<Int?>): List<Int> {
    val n = PlotColors.size
    val used = HashSet<Int>()
    val out = IntArray(colors.size) { -1 }
    val pending = mutableListOf<Int>()
    for ((i, raw) in colors.withIndex()) {
        if (raw != null && raw in 0 until n && raw !in used) {
            used.add(raw); out[i] = raw
        } else pending.add(i)
    }
    for (i in pending) {
        val pick = (0 until n).firstOrNull { it !in used } ?: (i % n)
        used.add(pick); out[i] = pick
    }
    return out.toList()
}

fun nextFreeColor(existing: List<Int?>): Int {
    val used = resolveColorIndices(existing).toSet()
    return (0 until PlotColors.size).firstOrNull { it !in used } ?: (existing.size % PlotColors.size)
}

fun projectPoint(x: Int, y: Int, size: Size): Offset {
    val padX = size.width * INSET
    val padY = size.height * INSET
    val innerW = size.width - 2 * padX
    val innerH = size.height - 2 * padY
    return Offset(padX + (x / 10000f) * innerW, padY + (1f - y / 10000f) * innerH)
}

val DrawScope.densityPx: Float get() = drawContext.density.density

fun DrawScope.drawChartGrid(size: Size) {
    val h = size.width / GRID_COUNT
    val v = size.height / GRID_COUNT
    val stroke = 0.5f * densityPx
    for (i in 0..GRID_COUNT) {
        drawLine(GridColor, Offset(0f, i * v), Offset(size.width, i * v), stroke)
        drawLine(GridColor, Offset(i * h, 0f), Offset(i * h, size.height), stroke)
    }
}

fun DrawScope.drawMidline(size: Size) {
    val padY = size.height * INSET
    val midY = padY + (size.height - 2 * padY) / 2
    drawLine(MidlineColor, Offset(0f, midY), Offset(size.width, midY), 1f * densityPx)
}

fun DrawScope.drawVLineAtX(size: Size, x: Int, color: Color, fullHeight: Boolean) {
    val padX = size.width * INSET
    val padY = size.height * INSET
    val px = padX + (x / 10000f) * (size.width - 2 * padX)
    val top = if (fullHeight) 0f else padY
    val bot = if (fullHeight) size.height else size.height - padY
    drawLine(color, Offset(px, top), Offset(px, bot), 1f * densityPx)
}
