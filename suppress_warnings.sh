#!/bin/sh

# Suppress warnings for Facebook SDK frameworks
find "${BUILT_PRODUCTS_DIR}" -name "FBSDKCoreKit*.framework" -type d -exec \
    xattr -w com.apple.xcode.CompilerWarnings "NO" {} \;

# Additional warning suppression for StoreKit deprecations
find "${BUILT_PRODUCTS_DIR}" -name "StoreKit.framework" -type d -exec \
    xattr -w com.apple.xcode.CompilerWarnings "NO" {} \; 