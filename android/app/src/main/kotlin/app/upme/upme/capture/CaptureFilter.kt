package app.upme.upme.capture

/**
 * Cheap native pre-filter so we only wake Flutter for notifications that
 * plausibly describe a money movement. The Dart brain makes the final call.
 * Keep these rules in sync with lib/brain/transaction_brain.dart.
 */
object CaptureFilter {
    private val currencyBefore = Regex(
        """(?i)(rp\.?|idr|usd|us\$|sgd|s\$|myr|\brm|eur|gbp|jpy|inr|php|thb|aud|a\$|[\$€£¥₹₱฿])\s?\d"""
    )
    private val currencyAfter = Regex("""(?i)\d[\d.,]*\s?(idr|usd|rupiah|eur|sgd|myr)\b""")
    private val otp = Regex(
        """(?i)\b(otp|kode verifikasi|verification code|one[- ]time password|jangan berikan|do not share|kode rahasia|passcode)\b"""
    )
    private val moneyVerb = Regex(
        """(?i)(berhasil|sukses|success|received|diterima|menerima|terima|paid|dibayar|bayar|pembayaran|payment|debit|kredit|credit|transfer|spent|purchase|pembelian|belanja|transaksi|transaction|withdraw|tarik|top ?up|refund|charged|masuk|keluar|dikirim|kirim|sent|gaji|salary|cashback)"""
    )
    private val promo = Regex(
        """(?i)\b(promo|diskon|discount|voucher|kupon|coupon|giveaway|flash sale|gratis|free|up to|hingga|s/d|min\.|minimal|dapatkan|get up|klaim|claim|buruan|hurry|limited)\b"""
    )
    private val completed = Regex(
        """(?i)(berhasil|sukses|successful|success|received|diterima|menerima|telah|has been|have been|was|were|done|completed|paid|dibayar|debited|credited)"""
    )

    fun looksLikeTransaction(text: String): Boolean {
        if (!(currencyBefore.containsMatchIn(text) || currencyAfter.containsMatchIn(text))) return false
        if (otp.containsMatchIn(text)) return false
        if (!moneyVerb.containsMatchIn(text)) return false
        if (promo.containsMatchIn(text) && !completed.containsMatchIn(text)) return false
        return true
    }
}
