package com.jamesdai.storycharts.data

import android.content.Context
import android.util.Base64
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONObject

const val DEMO_PASSWORD = "johnyappleseed"
private const val DEMO_EMAIL = "demo@storycharts.com"
// Pre-authenticated Cloudflare Access token for the demo account. Expires 2026-05-14.
private const val DEMO_TOKEN =
    "eyJhbGciOiJSUzI1NiIsImtpZCI6IjdmMmFhNGQ1MWZkNjU1MTZmNzE1MjEzMzQwYmE1MzFiMmUwZWUyMDJmYjJiZDM3MmUxYTUwNDc2YWQ0NWJkOTcifQ.eyJhdWQiOlsiNmQ0MDNiNjVhYmU4MTgzYTc4YTc3NWJmNWEzNTIyM2I3NGM5NmM2ZDdlOTA1MDEzNTA1MTNiZDExZmM2N2QwMCJdLCJlbWFpbCI6ImphbWVzZGFpQGxqcmVzb3VyY2VzLmNvbSIsImV4cCI6MTc3ODc3NDM1OSwiaWF0IjoxNzc2MTQ2MzU5LCJuYmYiOjE3NzYxNDYzNTksImlzcyI6Imh0dHBzOi8vc3RvcnljaGFydHMuY2xvdWRmbGFyZWFjY2Vzcy5jb20iLCJ0eXBlIjoiYXBwIiwiaWRlbnRpdHlfbm9uY2UiOiJIOGxYclpkb2lidXNyb0gxIiwic3ViIjoiZmRhNWI2ZjgtZGU5NS01ZTVlLWE0ZWQtZDQ1NmUwNTY5MmQyIiwiY291bnRyeSI6IlVTIiwicG9saWN5X2lkIjoiYjFlNzAzMTItOTA0Mi00ZjEwLTllMzItOTM1M2EzNWRkMmI5In0.KjaB7i062Tci-FoqKsYxtXlj2Qy6YEw9hC3oWXxkslIvk0z4HMO2D4_nnqoudu8x5i4AYG_UYhgBU3jqag1sE9GZaQyrgfH-QGxVb9y0Tko24h2ODW8NsazigRk-fJ04ocENrjXMbYS470OsjduxrLgf6IaGftE0ZXJRy42jzAhgKXD7ApRFIjE_kUBTvhCpvlXdaT4disKBzWSzguFMnKJG0d8guu__gTrMia1X31-FsB_TyimGvYxkEd7Ya-wNtEriSAJtDKnjy4ozshTem9vY0c_JvRE6pqaHH5VwO5uvYAZkugB1BdaEJYr531FUGyqJx3zIMQqsrtu9mc2E9A"

class AuthManager private constructor(context: Context) {
    private val prefs = run {
        val key = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
        EncryptedSharedPreferences.create(
            context, "storycharts_auth", key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated

    private val _userEmail = MutableStateFlow<String?>(null)
    val userEmail: StateFlow<String?> = _userEmail

    init {
        prefs.getString(KEY_TOKEN, null)?.let { token ->
            ApiClient.authToken = token
            _userEmail.value = prefs.getString(KEY_EMAIL, null)
            _isAuthenticated.value = true
        }
    }

    fun signInAsDemo() = setToken(DEMO_TOKEN, DEMO_EMAIL)

    fun signInWithToken(token: String) = setToken(token, decodeEmailFromJwt(token))

    fun signOut() {
        prefs.edit().remove(KEY_TOKEN).remove(KEY_EMAIL).apply()
        ApiClient.authToken = null
        _userEmail.value = null
        _isAuthenticated.value = false
    }

    private fun setToken(token: String, email: String?) {
        prefs.edit().putString(KEY_TOKEN, token).putString(KEY_EMAIL, email).apply()
        ApiClient.authToken = token
        _userEmail.value = email
        _isAuthenticated.value = true
    }

    private fun decodeEmailFromJwt(token: String): String? = try {
        val parts = token.split(".")
        if (parts.size < 2) null else {
            val payload = Base64.decode(parts[1], Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
            JSONObject(String(payload)).optString("email").ifEmpty { null }
        }
    } catch (_: Exception) { null }

    companion object {
        private const val KEY_TOKEN = "cf_access_token"
        private const val KEY_EMAIL = "cf_user_email"
        @Volatile private var INSTANCE: AuthManager? = null
        fun get(context: Context): AuthManager = INSTANCE ?: synchronized(this) {
            INSTANCE ?: AuthManager(context.applicationContext).also { INSTANCE = it }
        }
    }
}
