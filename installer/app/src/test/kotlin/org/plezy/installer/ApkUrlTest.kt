package org.plezy.installer

import org.junit.Assert.assertEquals
import org.junit.Test

class ApkUrlTest {

    @Test fun arm64_maps_to_arm64_apk() {
        assertEquals(
            "https://swag.obs1.duckdns.org/plezy-arm64.apk",
            apkUrlForAbi("arm64-v8a"),
        )
    }

    @Test fun x86_64_maps_to_x86_64_apk() {
        assertEquals(
            "https://swag.obs1.duckdns.org/plezy-x86_64.apk",
            apkUrlForAbi("x86_64"),
        )
    }

    @Test fun armeabi_v7a_maps_to_armv7_apk() {
        assertEquals(
            "https://swag.obs1.duckdns.org/plezy-armv7.apk",
            apkUrlForAbi("armeabi-v7a"),
        )
    }

    @Test fun unknown_abi_falls_back_to_armv7() {
        assertEquals(
            "https://swag.obs1.duckdns.org/plezy-armv7.apk",
            apkUrlForAbi("mips"),
        )
    }
}
