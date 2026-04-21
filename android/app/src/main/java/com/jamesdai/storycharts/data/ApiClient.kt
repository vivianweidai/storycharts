package com.jamesdai.storycharts.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException

class ApiException(val code: Int, msg: String) : IOException(msg)

object ApiClient {
    private val client = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true }
    private val JSON = "application/json; charset=utf-8".toMediaType()

    @Volatile var authToken: String? = null

    suspend fun listStories(): List<StoryListItem> = get("stories")
    suspend fun getStory(id: Int): StoryDetail = get("stories/$id")
    suspend fun createStory(title: String): CreateResponse =
        post("stories", buildJsonObject { put("title", JsonPrimitive(title)) })
    suspend fun updateStory(id: Int, title: String) {
        put<OKResponse>("stories/$id", buildJsonObject { put("title", JsonPrimitive(title)) })
    }
    suspend fun deleteStory(id: Int) { delete<OKResponse>("stories/$id") }

    suspend fun createPlot(storyId: Int, title: String, color: Int = -1): CreateResponse =
        post("stories/$storyId/plots", plotBody(title, color))
    suspend fun updatePlot(id: Int, title: String, color: Int = -1) {
        put<OKResponse>("plots/$id", plotBody(title, color))
    }
    suspend fun deletePlot(id: Int) { delete<OKResponse>("plots/$id") }

    suspend fun saveChartPoints(storyId: Int, points: List<ChartPointPayload>) {
        val arr = json.encodeToJsonElement(ListSerializer(ChartPointPayload.serializer()), points)
        post<OKResponse>("stories/$storyId/chartpoints", buildJsonObject { put("points", arr) })
    }

    suspend fun getMe(): User? = try { get<User>("auth/me") } catch (e: ApiException) {
        if (e.code == 401) null else throw e
    }

    suspend fun deleteAccount() { delete<OKResponse>("account") }

    private fun plotBody(title: String, color: Int) = buildJsonObject {
        put("title", JsonPrimitive(title))
        put("color", JsonPrimitive(color))
    }

    private suspend inline fun <reified T> get(path: String): T = request(path, "GET", null)
    private suspend inline fun <reified T> post(path: String, body: JsonElement): T = request(path, "POST", body)
    private suspend inline fun <reified T> put(path: String, body: JsonElement): T = request(path, "PUT", body)
    private suspend inline fun <reified T> delete(path: String): T = request(path, "DELETE", null)

    private suspend inline fun <reified T> request(
        path: String, method: String, body: JsonElement?,
    ): T = withContext(Dispatchers.IO) {
        val builder = Request.Builder()
            .url("${ApiConfig.BASE_URL}/$path")
            .addHeader("CF-Access-Client-Id", ApiConfig.CF_ACCESS_CLIENT_ID)
            .addHeader("CF-Access-Client-Secret", ApiConfig.CF_ACCESS_CLIENT_SECRET)
        authToken?.let { builder.addHeader("Cookie", "CF_Authorization=$it") }

        val rb = body?.let { json.encodeToString(JsonElement.serializer(), it).toRequestBody(JSON) }
        when (method) {
            "GET" -> builder.get()
            "DELETE" -> if (rb != null) builder.delete(rb) else builder.delete()
            "POST" -> builder.post(rb ?: "".toRequestBody(JSON))
            "PUT" -> builder.put(rb ?: "".toRequestBody(JSON))
        }

        client.newCall(builder.build()).execute().use { resp ->
            val text = resp.body?.string().orEmpty()
            if (!resp.isSuccessful) throw ApiException(resp.code, "HTTP ${resp.code}: $text")
            json.decodeFromString(text)
        }
    }
}
