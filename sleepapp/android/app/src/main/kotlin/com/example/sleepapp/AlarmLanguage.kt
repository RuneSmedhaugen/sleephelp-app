package com.example.sleepapp

import android.content.Context
import java.util.Locale

internal class AlarmLanguage(context: Context) {
    private val preferences = context.getSharedPreferences("rest_alarm_language", Context.MODE_PRIVATE)

    val locale: Locale
        get() = preferences.getString("locale", null)?.let(Locale::forLanguageTag)
            ?: Locale.getDefault()

    fun text(key: String, fallback: String): String = preferences.getString(key, null) ?: fallback

    fun save(locale: String, labels: Map<String, String>) {
        val update = preferences.edit().clear()
        for ((key, value) in labels) update.putString(key, value)
        update.putString("locale", locale).apply()
    }
}

internal class AlarmPermissionRequired(val code: String) : IllegalStateException()
