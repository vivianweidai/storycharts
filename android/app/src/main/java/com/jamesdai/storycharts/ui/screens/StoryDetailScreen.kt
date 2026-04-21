package com.jamesdai.storycharts.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jamesdai.storycharts.data.*
import com.jamesdai.storycharts.ui.chart.*
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoryDetailScreen(storyId: Int, onBack: () -> Unit) {
    val ctx = LocalContext.current
    val blocked = remember { BlockedUsers.get(ctx) }
    val scope = rememberCoroutineScope()

    var detail by remember { mutableStateOf<StoryDetail?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var chartPoints by remember { mutableStateOf<List<ChartPoint>>(emptyList()) }
    var highlightedPoint by remember { mutableStateOf<PointHighlight?>(null) }
    var playX by remember { mutableStateOf<Int?>(null) }
    var playJob by remember { mutableStateOf<Job?>(null) }
    val isPlaying by remember { derivedStateOf { playJob?.isActive == true } }
    var menuOpen by remember { mutableStateOf(false) }
    var showTitleDialog by remember { mutableStateOf(false) }
    var editTitle by remember { mutableStateOf("") }
    var editPlotName by remember { mutableStateOf("") }
    var editSceneLabel by remember { mutableStateOf("") }
    var showBlockConfirm by remember { mutableStateOf(false) }

    suspend fun load() {
        try {
            val d = ApiClient.getStory(storyId)
            detail = d
            chartPoints = d.chartPoints
        } catch (_: Exception) {}
        isLoading = false
    }

    LaunchedEffect(storyId) { load() }

    fun stopPlayback() {
        playJob?.cancel()
        playJob = null
        playX = null
    }

    fun play(resumeFrom: PointHighlight? = highlightedPoint) {
        val d = detail ?: return
        val scenes = playbackScenes(d.plots, chartPoints)
        if (scenes.isEmpty()) return
        val startIdx = resumeFrom?.let { hl ->
            scenes.indexOfFirst { it.plotIndex == hl.plotIndex && it.pointIndex == hl.pointIndex }
        }?.coerceAtLeast(0) ?: 0
        highlightedPoint = null
        playJob = scope.launch {
            runPlayback(buildSegments(scenes, startIdx),
                setPlayX = { playX = it }, setHighlight = { highlightedPoint = it })
            playX = null
        }
    }

    LaunchedEffect(detail?.story?.id, detail?.isOwner) {
        if (detail?.isOwner == false && playJob == null && highlightedPoint == null) {
            delay(3000)
            if (playJob == null && highlightedPoint == null) play()
        }
    }

    suspend fun saveAll() {
        try { ApiClient.saveChartPoints(storyId, chartPoints.toPayloads()) } catch (_: Exception) {}
    }

    fun savePlotName(hl: PointHighlight) {
        val d = detail ?: return
        val plot = d.plots.getOrNull(hl.plotIndex) ?: return
        val trimmed = editPlotName.trim().take(2000)
        if (trimmed.isEmpty() || trimmed == hl.plotTitle) return
        detail = d.copy(plots = d.plots.mapIndexed { i, p -> if (i == hl.plotIndex) p.copy(title = trimmed) else p })
        highlightedPoint = hl.copy(plotTitle = trimmed)
        val color = (plot.color ?: -1).takeIf { it >= 0 }
            ?: resolveColorIndices(d.plots.map { it.color })[hl.plotIndex]
        scope.launch { try { ApiClient.updatePlot(plot.id, trimmed, color) } catch (_: Exception) {} }
    }

    fun saveSceneLabel(hl: PointHighlight) {
        val d = detail ?: return
        val plot = d.plots.getOrNull(hl.plotIndex) ?: return
        val point = chartPoints.scenesFor(plot.id).getOrNull(hl.pointIndex) ?: return
        val trimmed = editSceneLabel.trim().take(2000)
        if (trimmed == hl.label) return
        chartPoints = chartPoints.map { if (it.id == point.id) it.copy(label = trimmed) else it }
        highlightedPoint = hl.copy(label = trimmed)
        scope.launch { saveAll() }
    }

    fun savePendingEdits() {
        highlightedPoint?.let {
            if (editPlotName != it.plotTitle) savePlotName(it)
            if (editSceneLabel != it.label) saveSceneLabel(it)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(detail?.story?.title ?: "Story", maxLines = 1) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, null)
                    }
                },
                actions = {
                    val d = detail ?: return@TopAppBar
                    IconButton(onClick = { menuOpen = true }) { Icon(Icons.Default.MoreVert, null) }
                    DropdownMenu(menuOpen, { menuOpen = false }) {
                        if (d.isOwner == true) {
                            DropdownMenuItem(text = { Text("Change Title") }, onClick = {
                                menuOpen = false; editTitle = d.story.title; showTitleDialog = true
                            })
                            DropdownMenuItem(text = { Text("Add Plot") }, onClick = {
                                menuOpen = false
                                scope.launch { addPlot(storyId, d, chartPoints) { load() } }
                            }, enabled = d.plots.size < 10)
                            DropdownMenuItem(text = { Text("Add Scene") }, onClick = {
                                menuOpen = false
                                scope.launch { addScene(storyId, d, chartPoints, highlightedPoint) { load() } }
                            }, enabled = chartPoints.size < 100 && d.plots.isNotEmpty())
                            DropdownMenuItem(text = { Text("Delete Story") }, onClick = {
                                menuOpen = false
                                scope.launch {
                                    try { ApiClient.deleteStory(storyId); onBack() } catch (_: Exception) {}
                                }
                            })
                        } else {
                            DropdownMenuItem(text = { Text(if (isPlaying) "Pause" else "Play") }, onClick = {
                                menuOpen = false
                                if (isPlaying) stopPlayback() else play()
                            })
                            DropdownMenuItem(text = { Text("Report this story") }, onClick = {
                                menuOpen = false
                                val subject = "Report StoryCharts story #${d.story.id}"
                                val body = "I'd like to report this story: " +
                                    "https://storycharts.com/story.html?id=${d.story.id}\n\nReason:\n"
                                val uri = Uri.Builder().scheme("mailto").opaquePart("privacy@storycharts.com")
                                    .appendQueryParameter("subject", subject)
                                    .appendQueryParameter("body", body).build()
                                ctx.startActivity(Intent(Intent.ACTION_SENDTO, uri))
                            })
                            DropdownMenuItem(text = { Text("Block this user") }, onClick = {
                                menuOpen = false; showBlockConfirm = true
                            })
                        }
                    }
                },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            val d = detail
            when {
                isLoading -> Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
                d == null -> Box(Modifier.fillMaxSize(), Alignment.Center) { Text("Not found.") }
                else -> {
                    ChartView(
                        plots = d.plots,
                        points = chartPoints,
                        isEditable = d.isOwner == true,
                        playX = playX,
                        highlightedPoint = highlightedPoint,
                        onPointTap = { hl ->
                            savePendingEdits()
                            stopPlayback()
                            highlightedPoint = if (hl == highlightedPoint) null else hl
                            hl?.let { editPlotName = it.plotTitle; editSceneLabel = it.label }
                        },
                        onDragSelected = { hl ->
                            savePendingEdits()
                            stopPlayback()
                            highlightedPoint = hl
                            editPlotName = hl.plotTitle
                            editSceneLabel = hl.label
                        },
                        onPointDragChanged = { pt, nx, ny ->
                            chartPoints = chartPoints.map {
                                if (it.id == pt.id) it.copy(x_pos = nx, y_val = ny) else it
                            }
                        },
                        onPointDragEnd = { scope.launch { saveAll() } },
                        modifier = Modifier.fillMaxWidth().aspectRatio(1f).padding(16.dp),
                    )
                    highlightedPoint?.let { hl ->
                        if (d.isOwner == true) EditPanel(
                            highlight = hl,
                            plotName = editPlotName, onPlotNameChange = { editPlotName = it },
                            onPlotSubmit = { savePlotName(hl) },
                            sceneLabel = editSceneLabel, onSceneLabelChange = { editSceneLabel = it },
                            onSceneSubmit = { saveSceneLabel(hl) },
                            onDeletePlot = {
                                scope.launch {
                                    try {
                                        ApiClient.deletePlot(d.plots[hl.plotIndex].id)
                                        highlightedPoint = null
                                        load()
                                    } catch (_: Exception) {}
                                }
                            },
                            onDeleteScene = {
                                val pt = chartPoints.scenesFor(d.plots[hl.plotIndex].id).getOrNull(hl.pointIndex)
                                    ?: return@EditPanel
                                chartPoints = chartPoints.filter { it.id != pt.id }
                                highlightedPoint = null
                                scope.launch { saveAll() }
                            },
                        ) else ReadOnlyPanel(hl)
                    }
                }
            }
        }
    }

    if (showTitleDialog) {
        AlertDialog(
            onDismissRequest = { showTitleDialog = false },
            title = { Text("Edit Story Name") },
            text = { OutlinedTextField(editTitle, { editTitle = it }, label = { Text("Title") }) },
            confirmButton = {
                TextButton(onClick = {
                    val trimmed = editTitle.trim().take(200).ifEmpty { "Untitled" }
                    detail = detail?.let { it.copy(story = it.story.copy(title = trimmed)) }
                    scope.launch { try { ApiClient.updateStory(storyId, trimmed) } catch (_: Exception) {} }
                    showTitleDialog = false
                }) { Text("OK") }
            },
            dismissButton = { TextButton(onClick = { showTitleDialog = false }) { Text("Cancel") } },
        )
    }

    if (showBlockConfirm) {
        AlertDialog(
            onDismissRequest = { showBlockConfirm = false },
            title = { Text("Block this user?") },
            text = { Text("Stories from this user will be hidden from your list on this device.") },
            confirmButton = {
                TextButton(onClick = {
                    detail?.story?.userid?.let { blocked.block(it) }
                    showBlockConfirm = false
                    onBack()
                }) { Text("Block") }
            },
            dismissButton = { TextButton(onClick = { showBlockConfirm = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun ReadOnlyPanel(h: PointHighlight) {
    Column(
        Modifier.fillMaxWidth().padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(h.plotTitle, color = h.color,
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold))
        if (h.label.isNotEmpty()) {
            Spacer(Modifier.height(6.dp))
            Text(h.label, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun EditPanel(
    highlight: PointHighlight,
    plotName: String, onPlotNameChange: (String) -> Unit, onPlotSubmit: () -> Unit,
    sceneLabel: String, onSceneLabelChange: (String) -> Unit, onSceneSubmit: () -> Unit,
    onDeletePlot: () -> Unit, onDeleteScene: () -> Unit,
) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                plotName, onPlotNameChange,
                modifier = Modifier.weight(1f),
                singleLine = true,
                textStyle = MaterialTheme.typography.titleSmall
                    .copy(color = highlight.color, fontWeight = FontWeight.SemiBold),
                label = { Text("Plot") },
                keyboardActions = KeyboardActions(onDone = { onPlotSubmit() }),
            )
            IconButton(onClick = onDeletePlot) {
                Icon(Icons.Default.Delete, null, tint = MaterialTheme.colorScheme.error)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                sceneLabel, onSceneLabelChange,
                modifier = Modifier.weight(1f),
                singleLine = true,
                label = { Text("Scene") },
                keyboardActions = KeyboardActions(onDone = { onSceneSubmit() }),
            )
            IconButton(onClick = onDeleteScene) {
                Icon(Icons.Default.Delete, null, tint = MaterialTheme.colorScheme.error)
            }
        }
    }
}

private val plotNames = listOf(
    "Plot A", "Plot B", "Plot C", "Plot D", "Plot E",
    "Plot F", "Plot G", "Plot H", "Plot I", "Plot J",
)

private suspend fun addPlot(
    storyId: Int, d: StoryDetail, chartPoints: List<ChartPoint>, reload: suspend () -> Unit,
) {
    if (d.plots.size >= 10) return
    val name = plotNames[d.plots.size % plotNames.size]
    val color = nextFreeColor(d.plots.map { it.color })
    try {
        val resp = ApiClient.createPlot(storyId, name, color)
        val seed = List(3) { ChartPointPayload(resp.id, (0..10000).random(), (0..10000).random(), "New scene") }
        ApiClient.saveChartPoints(storyId, chartPoints.toPayloads() + seed)
        reload()
    } catch (_: Exception) {}
}

private suspend fun addScene(
    storyId: Int, d: StoryDetail, chartPoints: List<ChartPoint>,
    hl: PointHighlight?, reload: suspend () -> Unit,
) {
    if (chartPoints.size >= 100) return
    val targetPlotId = when {
        hl != null && hl.plotIndex < d.plots.size -> d.plots[hl.plotIndex].id
        d.plots.isNotEmpty() -> d.plots.last().id
        else -> try { ApiClient.createPlot(storyId, plotNames[0], 0).id } catch (_: Exception) { return }
    }
    val payload = ChartPointPayload(targetPlotId, (0..10000).random(), (0..10000).random(), "New scene")
    try { ApiClient.saveChartPoints(storyId, chartPoints.toPayloads() + payload); reload() } catch (_: Exception) {}
}
