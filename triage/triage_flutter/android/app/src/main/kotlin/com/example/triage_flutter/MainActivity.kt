package com.example.triage_flutter

import android.graphics.Color
import android.content.Intent
import android.net.Uri
import android.provider.AlarmClock
import android.widget.Toast
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import android.webkit.JavascriptInterface
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.webkit.WebViewAssetLoader
import ai.desertant.redact.Redact
import kotlinx.coroutines.runBlocking
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val voiceInitWaiters = mutableListOf<MethodChannel.Result>()
    private val voiceRequests = mutableMapOf<String, MethodChannel.Result>()
    private var voiceWebView: WebView? = null
    private var voicePageLoaded = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "triage.apps")
            .setMethodCallHandler { call, result ->
                if (call.method != "launch") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val app = call.argument<String>("appName")
                // Exact allowlist: the backend cannot supply arbitrary intents,
                // package names, URLs, recipients, messages or alarm extras.
                val intent = when (app) {
                    "whatsapp" -> packageManager.getLaunchIntentForPackage("com.whatsapp")
                        ?: Intent(Intent.ACTION_VIEW, Uri.parse("whatsapp://"))
                    "calendar" -> Intent(Intent.ACTION_VIEW, Uri.parse("content://com.android.calendar/time/${System.currentTimeMillis()}"))
                    "maps" -> Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q="))
                    "mail" -> Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:"))
                    "clock" -> Intent(AlarmClock.ACTION_SET_ALARM).putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                    "notes" -> packageManager.getLaunchIntentForPackage("com.google.android.keep")
                        ?: Intent("android.intent.action.CREATE_NOTE")
                    "browser" -> Intent.makeMainSelectorActivity(Intent.ACTION_MAIN, Intent.CATEGORY_APP_BROWSER)
                    else -> null
                }
                if (intent == null) {
                    result.success(false)
                } else {
                    try {
                        startActivity(intent)
                        val label = if (app == "whatsapp") "WhatsApp" else app!!.replaceFirstChar { it.uppercase() }
                        Toast.makeText(this, "Launching $label...", Toast.LENGTH_SHORT).show()
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "triage.redact")
            .setMethodCallHandler { call, result ->
                if (call.method != "redact") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val texts = call.argument<List<String>>("texts")
                if (texts == null) {
                    result.error("invalid_input", "Text batch is required.", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        val sanitized = runBlocking {
                            Redact(applicationContext).use { engine ->
                                texts.map { engine.redaction(it).redactedText }
                            }
                        }
                        runOnUiThread { result.success(sanitized) }
                    } catch (error: Throwable) {
                        runOnUiThread {
                            result.error("redaction_failed", "On-device privacy check failed.", null)
                        }
                    }
                }.start()
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "triage.needle")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> initializeVoiceWebView(result)
                    "dispatch" -> dispatchVoiceRequest(call.argument<String>("message"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun initializeVoiceWebView(result: MethodChannel.Result) {
        if (voicePageLoaded) {
            result.success(null)
            return
        }
        voiceInitWaiters.add(result)
        if (voiceWebView != null) return

        val assetLoader = WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()
        val webView = WebView(this)
        voiceWebView = webView
        webView.setBackgroundColor(Color.TRANSPARENT)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = false
        webView.settings.allowFileAccess = false
        webView.settings.allowContentAccess = false
        webView.settings.allowFileAccessFromFileURLs = false
        webView.settings.allowUniversalAccessFromFileURLs = false
        webView.addJavascriptInterface(object {
            @JavascriptInterface
            fun postMessage(message: String) {
                mainHandler.post { completeVoiceRequest(message) }
            }
        }, "TriageVoice")
        webView.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView?,
                request: WebResourceRequest?,
            ): WebResourceResponse? = request?.url?.let { assetLoader.shouldInterceptRequest(it) }

            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?,
            ): Boolean = request?.url?.toString()?.startsWith(VOICE_ENGINE_URL) != true

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                if (url?.startsWith(VOICE_ENGINE_URL) == true) {
                    voicePageLoaded = true
                    voiceInitWaiters.toList().forEach { it.success(null) }
                    voiceInitWaiters.clear()
                }
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?,
            ) {
                super.onReceivedError(view, request, error)
                if (request?.isForMainFrame == true) {
                    failVoiceInitialization(error?.description?.toString() ?: "Local voice engine page failed to load.")
                }
            }
        }

        webView.visibility = View.INVISIBLE
        addContentView(webView, FrameLayout.LayoutParams(1, 1))
        webView.loadUrl(VOICE_ENGINE_URL)
    }

    private fun dispatchVoiceRequest(message: String?, result: MethodChannel.Result) {
        val webView = voiceWebView
        if (!voicePageLoaded || webView == null || message == null) {
            result.error("voice_not_ready", "Local voice engine is not ready.", null)
            return
        }
        val requestId = try {
            JSONObject(message).getString("requestId")
        } catch (_: Exception) {
            result.error("invalid_request", "Voice request is malformed.", null)
            return
        }
        voiceRequests[requestId] = result
        val encoded = JSONObject.quote(message)
        webView.evaluateJavascript("window.triageNeedleReceive($encoded)", null)
    }

    private fun completeVoiceRequest(message: String) {
        val payload = try {
            JSONObject(message)
        } catch (_: Exception) {
            return
        }
        val requestId = payload.optString("requestId")
        val result = voiceRequests.remove(requestId) ?: return
        if (payload.has("error")) {
            result.error("needle_error", payload.optString("error"), null)
        } else {
            result.success(payload.optJSONObject("result")?.toString() ?: "{}")
        }
    }

    private fun failVoiceInitialization(message: String) {
        voicePageLoaded = false
        voiceWebView?.destroy()
        voiceWebView = null
        voiceInitWaiters.toList().forEach { it.error("voice_asset_error", message, null) }
        voiceInitWaiters.clear()
    }

    override fun onDestroy() {
        voiceRequests.values.forEach { it.error("voice_closed", "Voice engine was closed.", null) }
        voiceRequests.clear()
        voiceInitWaiters.forEach { it.error("voice_closed", "Voice engine was closed.", null) }
        voiceInitWaiters.clear()
        voiceWebView?.let { webView ->
            (webView.parent as? android.view.ViewGroup)?.removeView(webView)
            webView.stopLoading()
            webView.destroy()
        }
        voiceWebView = null
        super.onDestroy()
    }

    companion object {
        private const val VOICE_ENGINE_URL =
            "https://appassets.androidplatform.net/assets/flutter_assets/assets/voice_engine/index.html"
    }
}
