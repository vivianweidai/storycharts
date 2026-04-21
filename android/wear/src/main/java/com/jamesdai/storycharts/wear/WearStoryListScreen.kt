package com.jamesdai.storycharts.wear

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.Text
import com.jamesdai.storycharts.data.ApiClient
import com.jamesdai.storycharts.data.BlockedUsers
import com.jamesdai.storycharts.data.StoryListItem

@Composable
fun WearStoryListScreen(onOpen: (Int, String) -> Unit) {
    val ctx = LocalContext.current
    val blocked = remember { BlockedUsers.get(ctx) }
    val blockedIds by blocked.ids.collectAsState()
    var stories by remember { mutableStateOf<List<StoryListItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        try { stories = ApiClient.listStories() } catch (_: Exception) {}
        isLoading = false
    }

    val visible = stories.filter { it.userid !in blockedIds }

    when {
        isLoading -> Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
        visible.isEmpty() -> Box(Modifier.fillMaxSize(), Alignment.Center) { Text("No stories") }
        else -> ScalingLazyColumn(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            items(visible, key = { it.id }) { story ->
                Chip(
                    onClick = { onOpen(story.id, story.title) },
                    label = { Text(story.title, maxLines = 2) },
                    colors = ChipDefaults.secondaryChipColors(),
                    modifier = Modifier.fillMaxSize(),
                )
            }
        }
    }
}
