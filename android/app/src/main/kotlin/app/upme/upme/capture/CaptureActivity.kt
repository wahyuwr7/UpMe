package app.upme.upme.capture

import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Transparent activity that floats the Flutter confirmation dialog on top of
 * whatever app the user is in. Runs the `captureMain` Dart entrypoint.
 */
class CaptureActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun getDartEntrypointFunctionName(): String = "captureMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun shouldAttachEngineToActivity(): Boolean = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = CaptureChannel.register(this, flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Another transaction arrived while the dialog is open: tell Dart to re-sync.
        channel?.invokeMethod("refresh", null)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setFinishOnTouchOutside(false)
    }

    companion object {
        fun intent(context: Context): Intent =
            Intent(context, CaptureActivity::class.java).addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION
            )
    }
}
