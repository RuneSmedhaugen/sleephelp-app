package com.example.sleepapp

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.UUID

internal data class WakeAlarm(
    val id: String,
    val hour: Int,
    val minute: Int,
    val days: List<Int>,
    val nextAt: Long = 0,
    val snoozedUntil: Long = 0,
    val finishBeforeMinutes: Int? = null,
    val fadeMinutes: Int? = null
) {
    fun nextAfter(now: Long): Long {
        // Start each candidate from today's calendar date so a DST adjustment
        // on one day cannot change the selected hour on subsequent days.
        for (offset in 0..7) {
            val day = Calendar.getInstance().apply {
                timeInMillis = now
                add(Calendar.DATE, offset)
            }
            val weekday = (day.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            if (days.isNotEmpty() && weekday !in days) continue
            day.set(Calendar.HOUR_OF_DAY, hour)
            day.set(Calendar.MINUTE, minute)
            day.set(Calendar.SECOND, 0)
            day.set(Calendar.MILLISECOND, 0)
            if (day.timeInMillis > now) return day.timeInMillis
        }
        error("Could not calculate the next alarm.")
    }
}

internal class WakeAlarms(private val context: Context) {
    private val store = context.getSharedPreferences("rest_wake_alarms", Context.MODE_PRIVATE)
    private val system = context.getSystemService(AlarmManager::class.java)

    private fun canSchedule() = Build.VERSION.SDK_INT < 31 || system.canScheduleExactAlarms()

    private fun notificationsAllowed(): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        return manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 26 ||
                manager.getNotificationChannel(RingingAlarmService.CHANNEL)?.importance !=
                    NotificationManager.IMPORTANCE_NONE)
    }

    private fun all() = store.all.keys.filter { it != LAST_RING }.mapNotNull(::get)

    fun get(id: String): WakeAlarm? {
        val value = store.getString(id, null) ?: return null
        val json = JSONObject(value)
        val days = json.getJSONArray("days")
        return WakeAlarm(
            id, json.getInt("hour"), json.getInt("minute"),
            List(days.length()) { days.getInt(it) },
            json.getLong("nextAt"), json.getLong("snoozedUntil"),
            json.optInt("finishBeforeMinutes", -1).takeIf { it >= 0 },
            json.optInt("fadeMinutes", -1).takeIf { it >= 0 }
        )
    }

    private fun put(alarm: WakeAlarm) {
        val value = JSONObject()
            .put("hour", alarm.hour)
            .put("minute", alarm.minute)
            .put("days", JSONArray(alarm.days))
            .put("nextAt", alarm.nextAt)
            .put("snoozedUntil", alarm.snoozedUntil)
            .put("finishBeforeMinutes", alarm.finishBeforeMinutes)
            .put("fadeMinutes", alarm.fadeMinutes)
        check(store.edit().putString(alarm.id, value.toString()).commit()) {
            "REST couldn't save this alarm."
        }
    }

    fun status(): Map<String, Any?> {
        val notifications = context.getSystemService(NotificationManager::class.java)
        val permissions = mutableListOf<String>()
        if (!canSchedule()) permissions.add("exact")
        if (!notificationsAllowed()) permissions.add("notifications")
        if (Build.VERSION.SDK_INT >= 34 && !notifications.canUseFullScreenIntent()) {
            permissions.add("fullScreen")
        }
        return mapOf(
            "alarms" to all().map {
                mapOf(
                    "id" to it.id, "hour" to it.hour, "minute" to it.minute, "days" to it.days,
                    "enabled" to (it.nextAt != 0L), "snoozed" to (it.snoozedUntil != 0L),
                    "nextAt" to it.nextAt.takeIf { canSchedule() },
                    "snoozedUntil" to it.snoozedUntil.takeIf { canSchedule() },
                    "finishBeforeMinutes" to it.finishBeforeMinutes, "fadeMinutes" to it.fadeMinutes
                )
            },
            "ringing" to RingingAlarmService.ringingId,
            "lastRing" to store.getLong(LAST_RING, 0),
            "permissions" to permissions
        )
    }

    fun save(
        id: String?, hour: Int, minute: Int, days: List<Int>, enabled: Boolean,
        finishBeforeMinutes: Int?, fadeMinutes: Int?
    ) {
        require(hour in 0..23 && minute in 0..59 && days.all { it in 1..7 })
        require(finishBeforeMinutes == null || finishBeforeMinutes in 0..720)
        require(fadeMinutes == null || fadeMinutes in 0..120)
        if (enabled) {
            if (!canSchedule()) throw AlarmPermissionRequired("exactRequired")
            if (!notificationsAllowed()) throw AlarmPermissionRequired("notificationsRequired")
        }
        val alarm = WakeAlarm(
            id ?: UUID.randomUUID().toString(), hour, minute, days.distinct().sorted(),
            finishBeforeMinutes = finishBeforeMinutes, fadeMinutes = fadeMinutes
        )
        val next = if (enabled) alarm.nextAfter(System.currentTimeMillis()) else 0
        val previous = get(alarm.id)
        put(alarm.copy(nextAt = next))
        try {
            if (enabled) schedule(alarm.id, next) else cancel(alarm.id)
        } catch (error: Exception) {
            if (previous != null) put(previous) else store.edit().remove(alarm.id).commit()
            throw error
        }
        cancel(alarm.id, snoozed = true)
        RingingAlarmService.dismiss(alarm.id)
    }

    fun delete(id: String) {
        check(store.edit().remove(id).commit()) { "REST couldn't delete this alarm." }
        cancel(id)
        cancel(id, snoozed = true)
        RingingAlarmService.dismiss(id)
    }

    fun stop(id: String) {
        val alarm = get(id) ?: return
        if (alarm.snoozedUntil != 0L) {
            put(alarm.copy(snoozedUntil = 0))
            cancel(id, snoozed = true)
        }
        RingingAlarmService.dismiss(id)
    }

    fun snooze(id: String) {
        if (id != RingingAlarmService.ringingId) return
        val alarm = get(id) ?: return
        val until = System.currentTimeMillis() + 9 * 60_000L
        put(alarm.copy(snoozedUntil = until))
        try {
            schedule(id, until, snoozed = true)
        } catch (error: Exception) {
            put(alarm)
            throw error
        }
        RingingAlarmService.dismiss(id)
    }

    fun fire(id: String, at: Long, snoozed: Boolean) {
        val alarm = get(id) ?: return
        if (at == 0L || at != (if (snoozed) alarm.snoozedUntil else alarm.nextAt)) return
        val next = if (snoozed) alarm.nextAt else if (alarm.days.isEmpty()) 0
            else alarm.nextAfter(maxOf(at, System.currentTimeMillis()))
        put(alarm.copy(nextAt = next, snoozedUntil = 0))
        store.edit().putLong(LAST_RING, System.currentTimeMillis()).apply()
        if (!snoozed) cancel(id, snoozed = true)
        RingingAlarmService.ring(context, id)
        if (!snoozed && next != 0L && canSchedule()) schedule(id, next)
    }

    fun restore() {
        if (!canSchedule()) return
        val now = System.currentTimeMillis()
        for (alarm in all()) {
            // A missed one-time alarm must not silently become tomorrow's alarm.
            val next = when {
                alarm.nextAt == 0L -> 0
                alarm.days.isNotEmpty() -> alarm.nextAfter(now)
                alarm.nextAt > now -> alarm.nextAt
                else -> 0
            }
            val snooze = alarm.snoozedUntil.takeIf { it > now } ?: 0
            put(alarm.copy(nextAt = next, snoozedUntil = snooze))
            if (next != 0L) schedule(alarm.id, next) else cancel(alarm.id)
            if (snooze != 0L) schedule(alarm.id, snooze, snoozed = true)
            else cancel(alarm.id, snoozed = true)
        }
    }

    private fun delivery(id: String, snoozed: Boolean) =
        Intent(context, WakeAlarmReceiver::class.java)
            .setAction(FIRE)
            .setData(Uri.parse("rest-alarm://fire/$id/$snoozed"))
            .putExtra("id", id)
            .putExtra("snoozed", snoozed)

    private fun schedule(id: String, at: Long, snoozed: Boolean = false) {
        val operation = PendingIntent.getBroadcast(
            context, 0, delivery(id, snoozed).putExtra("at", at),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val show = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        system.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), operation)
    }

    private fun cancel(id: String, snoozed: Boolean = false) {
        val operation = PendingIntent.getBroadcast(
            context, 0, delivery(id, snoozed),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        ) ?: return
        system.cancel(operation)
        operation.cancel()
    }

    companion object {
        private const val LAST_RING = "last_ring"
        const val FIRE = "com.example.sleepapp.ALARM_FIRE"
        const val SNOOZE = "com.example.sleepapp.ALARM_SNOOZE"
        const val STOP = "com.example.sleepapp.ALARM_STOP"
    }
}

class WakeAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarms = WakeAlarms(context)
        try {
            when (intent.action) {
                WakeAlarms.FIRE -> alarms.fire(
                    intent.getStringExtra("id") ?: return,
                    intent.getLongExtra("at", 0),
                    intent.getBooleanExtra("snoozed", false)
                )
                WakeAlarms.SNOOZE -> alarms.snooze(intent.getStringExtra("id") ?: return)
                WakeAlarms.STOP -> alarms.stop(intent.getStringExtra("id") ?: return)
                Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED,
                AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED -> alarms.restore()
            }
        } catch (error: Exception) {
            android.util.Log.e("RestAlarm", "Alarm action failed", error)
            if (intent.action == WakeAlarms.SNOOZE) {
                    val message = AlarmLanguage(context).text("snoozeError", "Couldn't snooze the alarm.")
                    android.widget.Toast.makeText(context, message, android.widget.Toast.LENGTH_SHORT).show()
            }
        }
    }
}
