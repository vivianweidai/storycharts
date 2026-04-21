package com.jamesdai.storycharts

import android.app.Application
import com.jamesdai.storycharts.data.AuthManager
import com.jamesdai.storycharts.data.BlockedUsers

class StoryChartsApp : Application() {
    override fun onCreate() {
        super.onCreate()
        AuthManager.get(this)
        BlockedUsers.get(this)
    }
}
