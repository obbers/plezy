package org.plezy.installer

private const val BASE = "https://swag.obs1.duckdns.org"

fun apkUrlForAbi(abi: String): String = when {
    abi.startsWith("arm64") -> "$BASE/plezy-arm64.apk"
    abi.startsWith("x86_64") -> "$BASE/plezy-x86_64.apk"
    else -> "$BASE/plezy-armv7.apk"
}
