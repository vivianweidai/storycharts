package com.jamesdai.storycharts.data

import kotlinx.serialization.Serializable

@Serializable
data class Story(val id: Int, val title: String, val userid: String)

@Serializable
data class Plot(
    val id: Int,
    val story_id: Int,
    val title: String,
    val sort_order: Int,
    val color: Int? = null,
)

@Serializable
data class ChartPoint(
    val id: Int,
    val story_id: Int,
    val plot_id: Int,
    val x_pos: Int,
    val y_val: Int,
    val label: String,
)

@Serializable
data class StoryDetail(
    val story: Story,
    val plots: List<Plot>,
    val chartPoints: List<ChartPoint>,
    val isOwner: Boolean? = null,
)

@Serializable
data class StoryListPoint(val x: Int, val y: Int)

@Serializable
data class StoryListPlot(
    val id: Int,
    val title: String,
    val color: Int? = null,
    val points: List<StoryListPoint>,
)

@Serializable
data class StoryListItem(
    val id: Int,
    val title: String,
    val userid: String,
    val plots: List<StoryListPlot>,
)

@Serializable
data class User(val userid: String, val email: String)

@Serializable
data class CreateResponse(val id: Int)

@Serializable
data class OKResponse(val ok: Boolean)

@Serializable
data class ChartPointPayload(
    val plot_id: Int,
    val x_pos: Int,
    val y_val: Int,
    val label: String,
)

fun List<ChartPoint>.scenesFor(plotId: Int): List<ChartPoint> =
    filter { it.plot_id == plotId }.sortedBy { it.x_pos }

fun List<ChartPoint>.toPayloads(): List<ChartPointPayload> =
    map { ChartPointPayload(it.plot_id, it.x_pos, it.y_val, it.label) }
