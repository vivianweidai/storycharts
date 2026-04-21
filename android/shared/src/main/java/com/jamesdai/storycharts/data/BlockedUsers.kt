package com.jamesdai.storycharts.data

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

// Per-device block list for Apple/Play UGC guidelines: stories from blocked
// users are hidden locally, server content is untouched.
class BlockedUsers private constructor(context: Context) {
    private val prefs = context.getSharedPreferences("blocked_users", Context.MODE_PRIVATE)

    private val _ids = MutableStateFlow(prefs.getStringSet(KEY, emptySet())?.toSet() ?: emptySet())
    val ids: StateFlow<Set<String>> = _ids

    fun block(userid: String) {
        if (userid.isEmpty()) return
        _ids.value = _ids.value + userid
        prefs.edit().putStringSet(KEY, _ids.value).apply()
    }

    companion object {
        private const val KEY = "blockedUserIDs"
        @Volatile private var INSTANCE: BlockedUsers? = null
        fun get(context: Context): BlockedUsers = INSTANCE ?: synchronized(this) {
            INSTANCE ?: BlockedUsers(context.applicationContext).also { INSTANCE = it }
        }
    }
}
