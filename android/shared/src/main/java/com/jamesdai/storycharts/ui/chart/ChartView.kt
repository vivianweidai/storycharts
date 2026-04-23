package com.jamesdai.storycharts.ui.chart

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.jamesdai.storycharts.data.ChartPoint
import com.jamesdai.storycharts.data.Plot
import com.jamesdai.storycharts.data.scenesFor
import kotlin.math.abs
import kotlin.math.hypot

private const val SNAP_THRESHOLD_PX = 14f
private val SweepColor = Color(0x592E63D4)
private val SnapColor = Color(0x590A69D9)

@Composable
fun ChartView(
    plots: List<Plot>,
    points: List<ChartPoint>,
    isEditable: Boolean,
    playX: Int? = null,
    highlightedPoint: PointHighlight? = null,
    onPointTap: (PointHighlight?) -> Unit = {},
    onPointDragChanged: (ChartPoint, Int, Int) -> Unit = { _, _, _ -> },
    onPointDragEnd: () -> Unit = {},
    onDragSelected: (PointHighlight) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val colorIdx = remember(plots) { resolveColorIndices(plots.map { it.color }) }
    val grouped = remember(plots, points) { plots.map { points.scenesFor(it.id) } }
    var draggingId by remember { mutableStateOf<Int?>(null) }
    var snappedX by remember { mutableStateOf<Int?>(null) }

    val borderColor = if (isEditable) Color(0xFF2E63D4).copy(alpha = 0.5f) else ChartStroke.copy(alpha = 0.5f)

    BoxWithConstraints(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(ChartBg)
            .border(BorderStroke(1.5.dp, borderColor), RoundedCornerShape(12.dp))
    ) {
        val size = Size(constraints.maxWidth.toFloat(), constraints.maxHeight.toFloat())

        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .pointerInput(plots, points) {
                    detectTapGestures { loc ->
                        if (draggingId != null) return@detectTapGestures
                        onPointTap(hitTest(loc, plots, grouped, size, colorIdx))
                    }
                }
                .then(
                    if (isEditable) Modifier.pointerInput(plots, points) {
                        detectDragGestures(
                            onDragStart = { offset ->
                                val hit = hitTest(offset, plots, grouped, size, colorIdx, radius = 44f) ?: return@detectDragGestures
                                draggingId = grouped[hit.plotIndex][hit.pointIndex].id
                                onDragSelected(hit)
                            },
                            onDragEnd = {
                                if (draggingId != null) onPointDragEnd()
                                draggingId = null; snappedX = null
                            },
                            onDragCancel = { draggingId = null; snappedX = null },
                            onDrag = { change, _ ->
                                val id = draggingId ?: return@detectDragGestures
                                val pt = points.firstOrNull { it.id == id } ?: return@detectDragGestures
                                val (rx, ry) = normalizedFromPixel(change.position, size)
                                val sx = snapXToNeighbor(rx, id, points, size)
                                snappedX = if (sx != rx) sx else null
                                onPointDragChanged(pt, sx, ry)
                                change.consume()
                            },
                        )
                    } else Modifier
                )
        ) {
            drawChartGrid(size)
            drawMidline(size)
            playX?.let { drawVLineAtX(size, it, SweepColor, fullHeight = true) }
            highlightedPoint?.let { drawHalo(size, it, grouped) }
            snappedX?.takeIf { draggingId != null }?.let { drawVLineAtX(size, it, SnapColor, fullHeight = false) }
            drawPlotLines(size, grouped, colorIdx)
            drawPlotDots(size, grouped, colorIdx, highlightedPoint)
        }
    }
}

private fun hitTest(
    loc: Offset, plots: List<Plot>, grouped: List<List<ChartPoint>>, size: Size,
    colorIdx: List<Int>, radius: Float = 30f,
): PointHighlight? {
    var best = radius
    var hit: PointHighlight? = null
    grouped.forEachIndexed { pi, pts ->
        pts.forEachIndexed { i, p ->
            val pos = projectPoint(p.x_pos, p.y_val, size)
            val d = hypot(loc.x - pos.x, loc.y - pos.y)
            if (d < best) {
                best = d
                hit = PointHighlight(pi, i, plots[pi].title, p.label, PlotColors[colorIdx[pi]])
            }
        }
    }
    return hit
}

private fun normalizedFromPixel(loc: Offset, size: Size): Pair<Int, Int> {
    val padX = size.width * INSET
    val padY = size.height * INSET
    val innerW = size.width - 2 * padX
    val innerH = size.height - 2 * padY
    val nx = ((loc.x - padX) / innerW * 10000f).coerceIn(0f, 10000f).toInt()
    val ny = ((1f - (loc.y - padY) / innerH) * 10000f).coerceIn(0f, 10000f).toInt()
    return nx to ny
}

private fun snapXToNeighbor(rawX: Int, excludeId: Int, points: List<ChartPoint>, size: Size): Int {
    val padX = size.width * INSET
    val innerW = size.width - 2 * padX
    val rawPx = padX + rawX / 10000f * innerW
    var best = SNAP_THRESHOLD_PX + 1
    var bestX = rawX
    for (p in points) if (p.id != excludeId) {
        val px = padX + p.x_pos / 10000f * innerW
        val d = abs(px - rawPx)
        if (d < best) { best = d; bestX = p.x_pos }
    }
    return bestX
}

private fun DrawScope.drawHalo(size: Size, h: PointHighlight, grouped: List<List<ChartPoint>>) {
    val pts = grouped.getOrNull(h.plotIndex) ?: return
    val pt = pts.getOrNull(h.pointIndex) ?: return
    val pos = projectPoint(pt.x_pos, pt.y_val, size)
    val r = 22f * densityPx
    drawCircle(h.color.copy(alpha = 0.08f), r, pos)
    drawCircle(h.color.copy(alpha = 0.25f), r, pos, style = Stroke(width = 1.5f * densityPx))
}

private fun DrawScope.drawPlotLines(size: Size, grouped: List<List<ChartPoint>>, colorIdx: List<Int>) {
    val w = 2.5f * densityPx
    grouped.forEachIndexed { pi, pts ->
        if (pts.size < 2) return@forEachIndexed
        val c = PlotColors[colorIdx[pi]]
        for (i in 1 until pts.size) {
            drawLine(c, projectPoint(pts[i - 1].x_pos, pts[i - 1].y_val, size),
                projectPoint(pts[i].x_pos, pts[i].y_val, size), w)
        }
    }
}

private fun DrawScope.drawPlotDots(
    size: Size, grouped: List<List<ChartPoint>>, colorIdx: List<Int>, highlight: PointHighlight?,
) {
    val d = densityPx
    grouped.forEachIndexed { pi, pts ->
        val c = PlotColors[colorIdx[pi]]
        pts.forEachIndexed { i, p ->
            val hl = highlight?.plotIndex == pi && highlight.pointIndex == i
            val r = if (hl) 7f * d else 5f * d
            drawCircle(c, r, projectPoint(p.x_pos, p.y_val, size))
        }
    }
}
