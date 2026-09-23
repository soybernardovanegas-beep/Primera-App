package com.primeraapp.recordatorios

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar

/**
 * Widget de la pantalla de inicio con los próximos recordatorios.
 *
 * La app guarda la lista completa (reminders_json) y aquí se calcula la
 * próxima vez de cada uno, así el widget sigue al día aunque la app no se abra.
 */
class RemindersWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = Calendar.getInstance()
        val upcoming = upcoming(widgetData.getString("reminders_json", null), now)

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.reminders_widget)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            views.setViewVisibility(
                R.id.widget_empty,
                if (upcoming.isEmpty()) View.VISIBLE else View.GONE,
            )
            ROWS.forEachIndexed { i, (whenId, titleId) ->
                val item = upcoming.getOrNull(i)
                val visibility = if (item == null) View.GONE else View.VISIBLE
                views.setViewVisibility(whenId, visibility)
                views.setViewVisibility(titleId, visibility)
                if (item != null) {
                    views.setTextViewText(whenId, describeWhen(item.first, now))
                    views.setTextViewText(titleId, item.second)
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        private val ROWS = listOf(
            R.id.when_0 to R.id.title_0,
            R.id.when_1 to R.id.title_1,
            R.id.when_2 to R.id.title_2,
            R.id.when_3 to R.id.title_3,
            R.id.when_4 to R.id.title_4,
            R.id.when_5 to R.id.title_5,
        )

        /** Próximos recordatorios activos, ordenados por hora. */
        private fun upcoming(json: String?, now: Calendar): List<Pair<Calendar, String>> {
            if (json == null) return emptyList()
            val list = JSONArray(json)
            val result = mutableListOf<Pair<Calendar, String>>()
            for (i in 0 until list.length()) {
                val r = list.getJSONObject(i)
                if (!r.optBoolean("enabled", true)) continue
                val weekdays = r.optJSONArray("weekdays")
                val days = (0 until (weekdays?.length() ?: 0)).map { weekdays!!.getInt(it) }.toSet()
                val next = nextOccurrence(
                    r.getInt("hour"),
                    r.getInt("minute"),
                    if (r.isNull("date")) null else r.getString("date"),
                    days,
                    now,
                ) ?: continue
                result.add(next to r.getString("title"))
            }
            return result.sortedBy { it.first.timeInMillis }
        }

        /** Misma lógica que Reminder.nextOccurrence en Dart (1 = lunes ... 7 = domingo). */
        private fun nextOccurrence(
            hour: Int,
            minute: Int,
            date: String?,
            weekdays: Set<Int>,
            now: Calendar,
        ): Calendar? {
            if (weekdays.isEmpty()) {
                if (date == null) return null
                val (y, m, d) = date.split("-").map { it.toInt() }
                val at = Calendar.getInstance().apply {
                    clear()
                    set(y, m - 1, d, hour, minute)
                }
                return if (at.after(now)) at else null
            }
            for (i in 0..7) {
                val day = (now.clone() as Calendar).apply {
                    add(Calendar.DAY_OF_YEAR, i)
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                val weekday = (day.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
                if (weekday in weekdays && day.after(now)) return day
            }
            return null
        }

        private val WEEKDAYS = listOf("dom", "lun", "mar", "mié", "jue", "vie", "sáb")
        private val MONTHS =
            listOf("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic")

        private fun describeWhen(at: Calendar, now: Calendar): String {
            val time = "%02d:%02d".format(at.get(Calendar.HOUR_OF_DAY), at.get(Calendar.MINUTE))
            val tomorrow = (now.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
            return when {
                sameDay(at, now) -> "Hoy $time"
                sameDay(at, tomorrow) -> "Mañana $time"
                else -> "${WEEKDAYS[at.get(Calendar.DAY_OF_WEEK) - 1]} " +
                    "${at.get(Calendar.DAY_OF_MONTH)} ${MONTHS[at.get(Calendar.MONTH)]} $time"
            }
        }

        private fun sameDay(a: Calendar, b: Calendar) =
            a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
                a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
    }
}
