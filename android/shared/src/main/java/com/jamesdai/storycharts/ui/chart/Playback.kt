package com.jamesdai.storycharts.ui.chart

import androidx.compose.ui.graphics.Color
import com.jamesdai.storycharts.data.ChartPoint
import com.jamesdai.storycharts.data.Plot
import com.jamesdai.storycharts.data.scenesFor
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlin.coroutines.coroutineContext

data class PointHighlight(
    val plotIndex: Int,
    val pointIndex: Int,
    val plotTitle: String,
    val label: String,
    val color: Color,
)

data class PlaybackScene(
    val plotIndex: Int,
    val pointIndex: Int,
    val x: Int,
    val label: String,
    val plotTitle: String,
    val color: Color,
)

data class PlaybackSegment(
    val startX: Int,
    val endX: Int,
    val point: PlaybackScene?,
    val sweepMs: Double,
    val pauseSeconds: Double,
)

private const val SWEEP_MS = 1500.0
private const val PAUSE_MIN = 2.0
private const val PAUSE_MAX = 4.0

private fun pauseSeconds(label: String): Double {
    val t = minOf(label.length / 60.0, 1.0)
    return PAUSE_MIN + t * (PAUSE_MAX - PAUSE_MIN)
}

fun playbackScenes(plots: List<Plot>, points: List<ChartPoint>): List<PlaybackScene> {
    val idx = resolveColorIndices(plots.map { it.color })
    val out = mutableListOf<PlaybackScene>()
    plots.forEachIndexed { pi, plot ->
        val c = PlotColors[idx[pi]]
        points.scenesFor(plot.id).forEachIndexed { si, pt ->
            out += PlaybackScene(pi, si, pt.x_pos, pt.label, plot.title, c)
        }
    }
    return out.sortedBy { it.x }
}

fun buildSegments(scenes: List<PlaybackScene>, startIdx: Int = 0): List<PlaybackSegment> {
    if (scenes.isEmpty() || startIdx >= scenes.size) return emptyList()
    val segs = mutableListOf<PlaybackSegment>()
    val first = scenes[startIdx]
    val firstStartX = if (startIdx > 0) scenes[startIdx].x else 0
    val firstSweep = if (startIdx > 0) 0.0 else SWEEP_MS * (first.x / 10000.0)
    segs += PlaybackSegment(firstStartX, first.x, first, firstSweep, pauseSeconds(first.label))
    for (i in (startIdx + 1) until scenes.size) {
        val dist = (scenes[i].x - scenes[i - 1].x).toDouble()
        segs += PlaybackSegment(
            scenes[i - 1].x, scenes[i].x, scenes[i],
            SWEEP_MS * (dist / 10000.0), pauseSeconds(scenes[i].label),
        )
    }
    val lastX = scenes.last().x
    if (lastX < 10000) {
        segs += PlaybackSegment(
            lastX, 10000, null,
            SWEEP_MS * ((10000 - lastX) / 10000.0), 0.0,
        )
    }
    return segs
}

suspend fun runPlayback(
    segments: List<PlaybackSegment>,
    fps: Double = 60.0,
    loop: Boolean = false,
    setPlayX: (Int?) -> Unit,
    setHighlight: (PointHighlight?) -> Unit,
) {
    val frameMs = (1000.0 / fps).toLong()
    val loopPauseMs = 1500L
    do {
        for (seg in segments) {
            if (!coroutineContext.isActive) return
            if (seg.sweepMs > 0) {
                val frames = maxOf(1, (seg.sweepMs / 1000.0 * fps).toInt())
                for (f in 0..frames) {
                    if (!coroutineContext.isActive) return
                    val t = f.toDouble() / frames
                    setPlayX(seg.startX + ((seg.endX - seg.startX) * t).toInt())
                    setHighlight(null)
                    delay(frameMs)
                }
            }
            if (!coroutineContext.isActive) return
            seg.point?.let { pt ->
                setPlayX(seg.endX)
                setHighlight(PointHighlight(pt.plotIndex, pt.pointIndex, pt.plotTitle, pt.label, pt.color))
                delay((seg.pauseSeconds * 1000).toLong())
            }
        }
        if (!loop) return
        setPlayX(null); setHighlight(null)
        delay(loopPauseMs)
    } while (coroutineContext.isActive && loop)
}
