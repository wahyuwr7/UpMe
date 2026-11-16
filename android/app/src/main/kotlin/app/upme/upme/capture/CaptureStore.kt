package app.upme.upme.capture

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Tiny persistent store shared by the notification listener (which runs without
 * Flutter) and the Flutter side (through [CaptureChannel]).
 *
 * The listener only *queues* raw notifications here. The Dart "brain" does the
 * real parsing, then moves items into the SQLite inbox and clears them here.
 */
class CaptureStore(context: Context) {
    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var enabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, true)
        set(v) = prefs.edit().putBoolean(KEY_ENABLED, v).apply()

    /** true = pop the confirmation dialog over other apps, false = post a quiet notification. */
    var popupEnabled: Boolean
        get() = prefs.getBoolean(KEY_POPUP, true)
        set(v) = prefs.edit().putBoolean(KEY_POPUP, v).apply()

    var mutedPackages: Set<String>
        get() = prefs.getStringSet(KEY_MUTED, null)?.toSet() ?: DEFAULT_MUTED
        set(v) = prefs.edit().putStringSet(KEY_MUTED, v.toSet()).apply()

    @Synchronized
    fun pending(): JSONArray = JSONArray(prefs.getString(KEY_PENDING, "[]"))

    @Synchronized
    fun addPending(item: JSONObject) {
        val arr = pending()
        arr.put(item)
        // Keep the queue bounded in case the user ignores it for months.
        val trimmed = JSONArray()
        val start = maxOf(0, arr.length() - MAX_PENDING)
        for (i in start until arr.length()) trimmed.put(arr.get(i))
        prefs.edit().putString(KEY_PENDING, trimmed.toString()).apply()
    }

    @Synchronized
    fun removePending(ids: Collection<String>) {
        val arr = pending()
        val kept = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optString("id") !in ids) kept.put(o)
        }
        prefs.edit().putString(KEY_PENDING, kept.toString()).apply()
    }

    /** Apps that posted something that looked like a transaction (for the mute list UI). */
    @Synchronized
    fun seenApps(): JSONObject = JSONObject(prefs.getString(KEY_SEEN, "{}"))

    @Synchronized
    fun recordSeen(pkg: String, label: String) {
        val o = seenApps()
        val entry = o.optJSONObject(pkg) ?: JSONObject()
        entry.put("label", label)
        entry.put("count", entry.optInt("count", 0) + 1)
        entry.put("lastSeen", System.currentTimeMillis())
        o.put(pkg, entry)
        prefs.edit().putString(KEY_SEEN, o.toString()).apply()
    }

    /**
     * Banks love re-posting/updating the same notification. Returns true if the
     * same content was seen in the last few minutes.
     */
    @Synchronized
    fun isDuplicate(fingerprint: String, now: Long = System.currentTimeMillis()): Boolean {
        val recent = JSONObject(prefs.getString(KEY_RECENT, "{}"))
        val cleaned = JSONObject()
        recent.keys().forEach { k ->
            val t = recent.optLong(k)
            if (now - t < DEDUPE_WINDOW_MS) cleaned.put(k, t)
        }
        val dup = cleaned.has(fingerprint)
        cleaned.put(fingerprint, now)
        prefs.edit().putString(KEY_RECENT, cleaned.toString()).apply()
        return dup
    }

    companion object {
        private const val PREFS = "upme_capture"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_POPUP = "popup"
        private const val KEY_MUTED = "muted"
        private const val KEY_PENDING = "pending"
        private const val KEY_SEEN = "seen"
        private const val KEY_RECENT = "recent"
        private const val MAX_PENDING = 200
        private const val DEDUPE_WINDOW_MS = 3 * 60 * 1000L

        /** Chat / social apps: amounts in chats are almost never your own transactions. */
        val DEFAULT_MUTED = setOf(
            "com.whatsapp", "com.whatsapp.w4b", "org.telegram.messenger",
            "com.instagram.android", "com.facebook.orca", "com.facebook.katana",
            "com.twitter.android", "com.discord", "jp.naver.line.android",
            "com.zhiliaoapp.musically", "com.ss.android.ugc.trill",
            "com.google.android.youtube",
        )
    }
}
