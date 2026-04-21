package com.jamesdai.storycharts

import android.app.Application
import com.jamesdai.storycharts.data.AuthManager
import com.jamesdai.storycharts.data.BlockedUsers

class StoryChartsApp : Application() {
    override fun onCreate() {
        super.onCreate()
        // Prime singletons on the main thread at launch so the first
        // composition doesn't block: AuthManager touches EncryptedSharedPreferences
        // (slow keystore init) and BlockedUsers reads another SharedPreferences.
        AuthManager.get(this)
        BlockedUsers.get(this)
    }
}
