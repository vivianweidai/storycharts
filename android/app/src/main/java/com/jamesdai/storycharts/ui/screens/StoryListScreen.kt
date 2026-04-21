package com.jamesdai.storycharts.ui.screens

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.jamesdai.storycharts.data.ApiClient
import com.jamesdai.storycharts.data.AuthManager
import com.jamesdai.storycharts.data.BlockedUsers
import com.jamesdai.storycharts.data.DEMO_PASSWORD
import com.jamesdai.storycharts.data.StoryListItem
import com.jamesdai.storycharts.ui.chart.ChartThumbnail
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoryListScreen(onOpen: (Int) -> Unit) {
    val ctx = LocalContext.current
    val auth = remember { AuthManager.get(ctx) }
    val blocked = remember { BlockedUsers.get(ctx) }
    val isAuth by auth.isAuthenticated.collectAsState()
    val email by auth.userEmail.collectAsState()
    val blockedIds by blocked.ids.collectAsState()

    var stories by remember { mutableStateOf<List<StoryListItem>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var menuOpen by remember { mutableStateOf(false) }
    var showDemoPrompt by remember { mutableStateOf(false) }
    var demoPassword by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()

    suspend fun load() {
        try { stories = ApiClient.listStories(); error = null }
        catch (_: Exception) { error = "Could not load stories" }
        isLoading = false
    }

    LaunchedEffect(isAuth) { isLoading = true; load() }

    val visible = remember(stories, blockedIds) { stories.filter { it.userid !in blockedIds } }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Story Charts") },
                actions = {
                    IconButton(onClick = { menuOpen = true }) {
                        Icon(if (isAuth) Icons.Default.AccountCircle else Icons.Default.MoreVert, null)
                    }
                    DropdownMenu(menuOpen, { menuOpen = false }) {
                        if (isAuth) {
                            email?.let {
                                DropdownMenuItem(
                                    text = { Text(it, style = MaterialTheme.typography.labelSmall) },
                                    onClick = {}, enabled = false,
                                )
                                HorizontalDivider()
                            }
                            DropdownMenuItem(text = { Text("Create Story") }, onClick = {
                                menuOpen = false
                                scope.launch {
                                    try {
                                        val resp = ApiClient.createStory("My Story")
                                        onOpen(resp.id)
                                    } catch (_: Exception) {}
                                }
                            })
                            DropdownMenuItem(text = { Text("Sign Out") }, onClick = {
                                menuOpen = false; auth.signOut()
                            })
                        } else {
                            DropdownMenuItem(text = { Text("Sign in with email") }, onClick = {
                                menuOpen = false
                                ctx.startActivity(Intent(Intent.ACTION_VIEW,
                                    Uri.parse("https://storycharts.com/api/auth/login?app=1")))
                            })
                            DropdownMenuItem(text = { Text("Demo account") }, onClick = {
                                menuOpen = false; demoPassword = ""; showDemoPrompt = true
                            })
                        }
                    }
                },
            )
        },
    ) { padding ->
        when {
            isLoading -> Box(Modifier.padding(padding).fillMaxSize(), Alignment.Center) {
                CircularProgressIndicator()
            }
            error != null -> Box(Modifier.padding(padding).fillMaxSize(), Alignment.Center) {
                Text(error!!)
            }
            visible.isEmpty() -> Box(Modifier.padding(padding).fillMaxSize(), Alignment.Center) {
                Text("No stories yet.", color = Color.Gray)
            }
            else -> LazyColumn(
                Modifier.padding(padding).fillMaxSize().padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                contentPadding = PaddingValues(vertical = 16.dp),
            ) {
                items(visible, key = { it.id }) { story ->
                    StoryCard(story) { onOpen(story.id) }
                }
            }
        }
    }

    if (showDemoPrompt) {
        AlertDialog(
            onDismissRequest = { showDemoPrompt = false },
            title = { Text("Demo Account") },
            text = {
                Column {
                    Text("Enter the demo account password.")
                    Spacer(Modifier.height(8.dp))
                    OutlinedTextField(demoPassword, { demoPassword = it }, label = { Text("Password") })
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    if (demoPassword == DEMO_PASSWORD) auth.signInAsDemo()
                    showDemoPrompt = false
                }) { Text("Sign In") }
            },
            dismissButton = { TextButton(onClick = { showDemoPrompt = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun StoryCard(story: StoryListItem, onClick: () -> Unit) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .border(1.dp, Color(0xFFE0E0E0), RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surface)
            .clickable(onClick = onClick),
    ) {
        ChartThumbnail(story.plots, Modifier.padding(12.dp))
        HorizontalDivider()
        Text(
            story.title,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            maxLines = 1,
        )
    }
}
