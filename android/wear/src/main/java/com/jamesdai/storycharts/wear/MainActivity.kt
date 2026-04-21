package com.jamesdai.storycharts.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { WearApp() }
    }
}

@Composable
private fun WearApp() {
    MaterialTheme {
        val nav = rememberSwipeDismissableNavController()
        SwipeDismissableNavHost(nav, startDestination = "list") {
            composable("list") {
                WearStoryListScreen(onOpen = { id, title ->
                    nav.navigate("story/$id?title=${title.take(30)}")
                })
            }
            composable(
                "story/{id}?title={title}",
                arguments = listOf(
                    navArgument("id") { type = NavType.IntType },
                    navArgument("title") { type = NavType.StringType; defaultValue = "" },
                ),
            ) { entry ->
                val id = entry.arguments?.getInt("id") ?: 0
                val title = entry.arguments?.getString("title").orEmpty()
                WearStoryDetailScreen(storyId = id, title = title)
            }
        }
    }
}
