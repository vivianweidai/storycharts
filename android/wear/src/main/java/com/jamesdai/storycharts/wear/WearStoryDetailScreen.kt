package com.jamesdai.storycharts.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.Text
import com.jamesdai.storycharts.data.ApiClient
import com.jamesdai.storycharts.data.StoryDetail
import com.jamesdai.storycharts.ui.chart.ChartView
import com.jamesdai.storycharts.ui.chart.PointHighlight
import com.jamesdai.storycharts.ui.chart.buildSegments
import com.jamesdai.storycharts.ui.chart.playbackScenes
import com.jamesdai.storycharts.ui.chart.runPlayback
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun WearStoryDetailScreen(storyId: Int, title: String) {
    var detail by remember { mutableStateOf<StoryDetail?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var playX by remember { mutableStateOf<Int?>(null) }
    var highlighted by remember { mutableStateOf<PointHighlight?>(null) }
    var playJob by remember { mutableStateOf<Job?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(storyId) {
        try { detail = ApiClient.getStory(storyId) } catch (_: Exception) {}
        isLoading = false
        detail?.let {
            delay(1000)
            val scenes = playbackScenes(it.plots, it.chartPoints)
            if (scenes.isNotEmpty()) {
                playJob = scope.launch {
                    runPlayback(
                        buildSegments(scenes), fps = 30.0, loop = true,
                        setPlayX = { x -> playX = x },
                        setHighlight = { h -> highlighted = h },
                    )
                }
            }
        }
    }

    DisposableEffect(Unit) {
        onDispose { playJob?.cancel() }
    }

    val d = detail
    when {
        isLoading -> Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
        d == null -> Box(Modifier.fillMaxSize(), Alignment.Center) { Text("Failed to load") }
        else -> Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()),
        ) {
            if (title.isNotBlank()) {
                Text(
                    title,
                    modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 4.dp),
                    maxLines = 1,
                )
            }
            ChartView(
                plots = d.plots,
                points = d.chartPoints,
                isEditable = false,
                playX = playX,
                highlightedPoint = highlighted,
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1f)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            )
            val scenes = remember(d) { playbackScenes(d.plots, d.chartPoints) }
            Column(
                Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                scenes.forEachIndexed { i, sc ->
                    val active = highlighted?.plotIndex == sc.plotIndex &&
                        highlighted?.pointIndex == sc.pointIndex
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(4.dp))
                            .background(if (active) sc.color.copy(alpha = 0.22f) else Color.Transparent)
                            .padding(horizontal = 6.dp, vertical = 3.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(Modifier.size(6.dp).clip(RoundedCornerShape(50)).background(sc.color))
                        Spacer(Modifier.width(6.dp))
                        Text(
                            if (sc.label.isEmpty()) "—" else sc.label,
                            maxLines = 2,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}
