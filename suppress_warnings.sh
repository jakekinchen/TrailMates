#!/bin/sh

# Warning suppression for StoreKit deprecations
find "${BUILT_PRODUCTS_DIR}" -name "StoreKit.framework" -type d -exec \
    xattr -w com.apple.xcode.CompilerWarnings "NO" {} \; 