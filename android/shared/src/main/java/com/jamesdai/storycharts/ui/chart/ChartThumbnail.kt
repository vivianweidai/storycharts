package com.jamesdai.storycharts.ui.chart

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.jamesdai.storycharts.data.StoryListPlot

private const val GOLDEN = 1.618f

@Composable
fun ChartThumbnail(plots: List<StoryListPlot>, modifier: Modifier = Modifier) {
    val colorIdx = remember(plots) { resolveColorIndices(plots.map { it.color }) }
    val sorted = remember(plots) { plots.map { it.points.sortedBy { p -> p.x } } }

    Canvas(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(GOLDEN)
            .clip(RoundedCornerShape(8.dp))
            .background(ChartBg)
    ) {
        drawChartGrid(size)
        drawMidline(size)
        val lineW = 2f * densityPx
        val dotR = 4f * densityPx
        sorted.forEachIndexed { pi, pts ->
            val c = PlotColors[colorIdx[pi]]
            if (pts.size > 1) {
                for (i in 1 until pts.size) {
                    drawLine(c, projectPoint(pts[i - 1].x, pts[i - 1].y, size),
                        projectPoint(pts[i].x, pts[i].y, size), lineW)
                }
            }
            for (p in pts) drawCircle(c, dotR, projectPoint(p.x, p.y, size))
        }
    }
}
