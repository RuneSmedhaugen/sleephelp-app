package com.example.sleepapp

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import java.text.DateFormat
import java.util.Date

class RingingAlarmService : Service() {
    private val language by lazy { AlarmLanguage(this) }
    private var player: MediaPlayer? = null
    private var fallbackTone: ToneGenerator? = null
    private var focus: AudioFocusRequest? = null
    private val alarms = linkedSetOf<String>()
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { ringingId?.let(::remove) }
    private val beep = object : Runnable {
        override fun run() {
            fallbackTone?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 650)
            if (ringingId != null) handler.postDelayed(this, 1400)
        }
    }
    private val alarmAudio = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    override fun onBind(intent: Intent?) = null

    override fun onCreate() {
        super.onCreate()
        current = this
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(
                CHANNEL, language.text("alarmChannel", "Wake-up alarms"), NotificationManager.IMPORTANCE_HIGH
            )
            channel.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            channel.setSound(null, null) // The alarm service plays the looping alarm tone.
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getStringExtra("id")
        val accepted = id != null && pending.remove(id) && WakeAlarms(this).get(id) != null
        if (accepted) alarms.add(requireNotNull(id))
        if (alarms.isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }
        if (ringingId == null) showNext()
        return START_NOT_STICKY
    }

    private fun showNext() {
        val id = alarms.first()
        ringingId = id
        startForeground(NOTIFICATION_ID, notification(id))
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, 10 * 60_000L)
        if (player == null && fallbackTone == null) playAlarm()
    }

    private fun remove(id: String) {
        alarms.remove(id)
        if (id != ringingId) return
        if (alarms.isEmpty()) {
            ringingId = null
            handler.removeCallbacks(timeout)
            releaseAudio()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } else {
            showNext()
        }
    }

    private fun notification(id: String): Notification {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val screen = PendingIntent.getActivity(
            this, 0,
            Intent(this, RingingAlarmActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .setData(Uri.parse("rest-alarm://ringing/$id")),
            flags
        )
        fun action(name: String) = PendingIntent.getBroadcast(
            this, 0,
            Intent(this, WakeAlarmReceiver::class.java).setAction(name)
                .setData(Uri.parse("rest-alarm://action/$id")).putExtra("id", id),
            flags
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
            else Notification.Builder(this).setPriority(Notification.PRIORITY_MAX)
        builder.setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(language.text("alarmTitle", "REST alarm"))
            .setContentText(language.text("alarmAlertDetail", "Snooze for 9 minutes or stop the alarm."))
            .setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setContentIntent(screen)
            .setFullScreenIntent(screen, true)
            .addAction(Notification.Action.Builder(null, language.text("snooze", "Snooze"), action(WakeAlarms.SNOOZE)).build())
            .addAction(Notification.Action.Builder(null, language.text("stop", "Stop"), action(WakeAlarms.STOP)).build())
        if (Build.VERSION.SDK_INT >= 31) {
            builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        }
        return builder.build()
    }

    private fun playAlarm() {
        val audio = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(alarmAudio)
                .setOnAudioFocusChangeListener { }
                .build()
            if (audio.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                focus = request
            }
        }
        for (tone in listOf(RingtoneManager.TYPE_ALARM, RingtoneManager.TYPE_RINGTONE)) {
            val uri = RingtoneManager.getDefaultUri(tone) ?: continue
            val candidate = MediaPlayer()
            try {
                candidate.setAudioAttributes(alarmAudio)
                candidate.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
                candidate.setDataSource(this, uri)
                candidate.isLooping = true
                candidate.setOnPreparedListener { if (player === it) it.start() }
                candidate.setOnErrorListener { failed, _, _ ->
                    if (player === failed) {
                        player = null
                        failed.release()
                        playFallback()
                    }
                    true
                }
                player = candidate
                candidate.prepareAsync()
                return
            } catch (error: Exception) {
                if (player === candidate) player = null
                candidate.release()
                android.util.Log.w("RestAlarm", "Could not open alarm tone", error)
            }
        }
        playFallback()
    }

    private fun playFallback() {
        if (ringingId == null || fallbackTone != null) return
        try {
            fallbackTone = ToneGenerator(AudioManager.STREAM_ALARM, 80)
            handler.post(beep)
        } catch (error: RuntimeException) {
            android.util.Log.w("RestAlarm", "Could not play fallback alarm tone", error)
        }
    }

    private fun releaseAudio() {
        player?.release()
        player = null
        handler.removeCallbacks(beep)
        fallbackTone?.release()
        fallbackTone = null
        if (Build.VERSION.SDK_INT >= 26) {
            focus?.let { getSystemService(AudioManager::class.java).abandonAudioFocusRequest(it) }
            focus = null
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(timeout)
        releaseAudio()
        if (current === this) {
            ringingId = null
            current = null
        }
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "rest_wake_alarms"
        private const val NOTIFICATION_ID = 4021
        private val pending = mutableSetOf<String>()
        private var current: RingingAlarmService? = null
        var ringingId: String? = null
            private set

        internal fun ring(context: Context, id: String) {
            pending.add(id)
            val intent = Intent(context, RingingAlarmService::class.java).putExtra("id", id)
            try {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
                else context.startService(intent)
            } catch (error: Exception) {
                pending.remove(id)
                throw error
            }
        }

        internal fun dismiss(id: String) {
            pending.remove(id)
            current?.remove(id)
        }
    }
}

class RingingAlarmActivity : Activity() {
    private val language by lazy { AlarmLanguage(this) }
    private val handler = Handler(Looper.getMainLooper())
    private val checkRinging = object : Runnable {
        override fun run() {
            if (RingingAlarmService.ringingId == null) finish()
            else handler.postDelayed(this, 400)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(32, 24, 32, 24)
            setBackgroundColor(0xff0b0d12.toInt())
        }
        layout.addView(TextView(this).apply {
            text = DateFormat.getTimeInstance(DateFormat.SHORT, language.locale).format(Date())
            textSize = 48f
            setTextColor(0xfff1f4fa.toInt())
        })
        layout.addView(TextView(this).apply {
            text = language.text("alarmTitle", "REST alarm")
            textSize = 20f
            setTextColor(0xffc399ff.toInt())
            setPadding(0, 0, 0, 22)
        })
        layout.addView(Button(this).apply {
            text = language.text("snoozeMinutes", "Snooze · 9 min")
            setOnClickListener { handleAlarm(snooze = true) }
        })
        layout.addView(Button(this).apply {
            text = language.text("stop", "Stop")
            setOnClickListener { handleAlarm(snooze = false) }
        })
        setContentView(layout)
    }

    override fun onResume() {
        super.onResume()
        handler.post(checkRinging)
    }

    override fun onPause() {
        handler.removeCallbacks(checkRinging)
        super.onPause()
    }

    private fun handleAlarm(snooze: Boolean) {
        val id = RingingAlarmService.ringingId ?: return finish()
        try {
            val alarms = WakeAlarms(this)
            if (snooze) alarms.snooze(id) else alarms.stop(id)
            if (RingingAlarmService.ringingId == null) finish()
        } catch (error: Exception) {
            android.util.Log.e("RestAlarm", "Alarm action failed", error)
            val message = language.text("alarmUpdateError", "Couldn't update the alarm.")
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        }
    }
}
