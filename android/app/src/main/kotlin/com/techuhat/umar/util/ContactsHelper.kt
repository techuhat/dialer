package com.techuhat.umar.util

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.provider.ContactsContract.PhoneLookup
import androidx.core.content.ContextCompat
import com.techuhat.umar.R

/** Contact lookups and avatars for the native call surfaces (notifications). */
object ContactsHelper {
    class Match(val name: String, val thumbnailUri: String?)

    private const val CACHE_TTL_MS = 5 * 60_000L
    private const val AVATAR_PX = 192

    /** Same palette and hash as `ContactAvatar` in Flutter, so a caller keeps one colour everywhere. */
    private val AVATAR_COLORS = intArrayOf(
        0xFF1E88E5.toInt(), 0xFF43A047.toInt(), 0xFFE53935.toInt(), 0xFF8E24AA.toInt(),
        0xFFF4511E.toInt(), 0xFF00897B.toInt(), 0xFFD81B60.toInt(), 0xFF5E35B1.toInt(),
    )

    private val PROJECTION = arrayOf(
        PhoneLookup.DISPLAY_NAME,
        PhoneLookup.NORMALIZED_NUMBER,
        PhoneLookup.NUMBER,
        PhoneLookup.PHOTO_THUMBNAIL_URI,
    )

    private val cache = HashMap<String, Pair<Match?, Long>>()

    @Synchronized
    fun lookup(context: Context, number: String?): Match? {
        val key = PhoneNumbers.key(number)
        if (key.isEmpty() || number == null) return null
        val now = System.currentTimeMillis()
        cache[key]?.let { (match, at) -> if (now - at < CACHE_TTL_MS) return match }
        return query(context, number, key).also { cache[key] = it to now }
    }

    // PhoneLookup matches loosely (7 trailing digits); require the full subscriber key to agree.
    private fun query(context: Context, number: String, key: String): Match? = try {
        val uri = Uri.withAppendedPath(PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number))
        context.contentResolver.query(uri, PROJECTION, null, null, null)?.use { cursor ->
            var match: Match? = null
            while (match == null && cursor.moveToNext()) {
                val name = cursor.getString(0)?.trim()
                val stored = cursor.getString(1) ?: cursor.getString(2)
                if (!name.isNullOrEmpty() && PhoneNumbers.key(stored) == key) {
                    match = Match(name, cursor.getString(3))
                }
            }
            match
        }
    } catch (_: Exception) {
        null
    }

    fun avatar(context: Context, match: Match?, title: String): Bitmap =
        match?.thumbnailUri?.let { decodeCircle(context, it) } ?: letterAvatar(context, title)

    private fun decodeCircle(context: Context, uri: String): Bitmap? = try {
        context.contentResolver.openInputStream(Uri.parse(uri))
            ?.use(BitmapFactory::decodeStream)
            ?.let(::circleCrop)
    } catch (_: Exception) {
        null
    }

    private fun circleCrop(source: Bitmap): Bitmap {
        val side = minOf(source.width, source.height)
        val left = (source.width - side) / 2
        val top = (source.height - side) / 2
        val output = Bitmap.createBitmap(AVATAR_PX, AVATAR_PX, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val bounds = RectF(0f, 0f, AVATAR_PX.toFloat(), AVATAR_PX.toFloat())
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        canvas.drawOval(bounds, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(source, Rect(left, top, left + side, top + side), bounds, paint)
        return output
    }

    private fun letterAvatar(context: Context, title: String): Bitmap {
        val output = Bitmap.createBitmap(AVATAR_PX, AVATAR_PX, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val size = AVATAR_PX.toFloat()
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = AVATAR_COLORS[Math.floorMod(title.hashCode(), AVATAR_COLORS.size)]
        }
        canvas.drawOval(RectF(0f, 0f, size, size), fill)

        val initials = initials(title)
        if (initials.isEmpty()) {
            val inset = (AVATAR_PX * 0.22f).toInt()
            ContextCompat.getDrawable(context, R.drawable.ic_avatar_person)?.apply {
                setBounds(inset, inset, AVATAR_PX - inset, AVATAR_PX - inset)
                draw(canvas)
            }
            return output
        }

        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textSize = size * if (initials.length > 1) 0.38f else 0.45f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }
        val bounds = Rect()
        text.getTextBounds(initials, 0, initials.length, bounds)
        canvas.drawText(initials, size / 2f, size / 2f + bounds.height() / 2f - bounds.bottom, text)
        return output
    }

    /** First letters of the first and last word; empty for numbers, which get a person glyph. */
    private fun initials(title: String): String {
        val words = title.trim().split(Regex("\\s+")).filter { it.firstOrNull()?.isLetter() == true }
        if (words.isEmpty()) return ""
        val first = words.first().first()
        val last = if (words.size > 1) words.last().first().toString() else ""
        return "$first$last".uppercase()
    }
}
