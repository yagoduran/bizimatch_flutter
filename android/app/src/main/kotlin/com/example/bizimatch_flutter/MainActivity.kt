package com.example.bizimatch_flutter

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity : FlutterFragmentActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		GoogleMobileAdsPlugin.registerNativeAdFactory(
			flutterEngine,
			NATIVE_AD_FACTORY_ID,
			NativeAdFactoryExample(layoutInflater),
		)
	}

	override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
		GoogleMobileAdsPlugin.unregisterNativeAdFactory(
			flutterEngine,
			NATIVE_AD_FACTORY_ID,
		)
		super.cleanUpFlutterEngine(flutterEngine)
	}

	companion object {
		private const val NATIVE_AD_FACTORY_ID = "discover_native_ad_factory"
	}
}
