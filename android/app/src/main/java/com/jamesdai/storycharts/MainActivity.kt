package com.jamesdai.storycharts

import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.fillMaxSize
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.NavType
import androidx.navigation.navArgument
import com.jamesdai.storycharts.data.AuthManager
import com.jamesdai.storycharts.ui.screens.StoryDetailScreen
import com.jamesdai.storycharts.ui.screens.StoryListScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAuthIntent(intent?.data)

        setContent {
            MaterialTheme {
                Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    val nav = rememberNavController()
                    NavHost(nav, startDestination = "list") {
                        composable("list") {
                            StoryListScreen(
                                onOpen = { id -> nav.navigate("story/$id") },
                            )
                        }
                        composable(
                            "story/{id}",
                            arguments = listOf(navArgument("id") { type = NavType.IntType }),
                        ) { entry ->
                            val id = entry.arguments?.getInt("id") ?: 0
                            StoryDetailScreen(storyId = id, onBack = { nav.popBackStack() })
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        handleAuthIntent(intent.data)
    }

    private fun handleAuthIntent(uri: Uri?) {
        if (uri == null || uri.scheme != "storycharts") return
        val token = uri.getQueryParameter("token") ?: return
        if (token.isNotEmpty()) AuthManager.get(this).signInWithToken(token)
    }
}
