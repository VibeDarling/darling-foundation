# Artifact identity from darling-swift a332a820861555d2e7076b0648da51094386e9d1,
# tracked libswiftFoundation.dylib LFS pointer. Update with that pinned source metadata.
function(foundation_validate_swift_overlay overlay)
    set(expected_sha256 "5668036099d1df6fee218a63c96777b9e76a75b629297250ff081a64f37dd582")
    if(NOT EXISTS "${overlay}" OR IS_DIRECTORY "${overlay}")
        message(FATAL_ERROR
            "Required Swift Foundation overlay is missing: ${overlay}. Hydrate the pinned "
            "darling-swift dependency with git lfs pull --include=libswiftFoundation.dylib.")
    endif()
    file(SHA256 "${overlay}" actual_sha256)
    if(NOT actual_sha256 STREQUAL expected_sha256)
        message(FATAL_ERROR
            "Swift Foundation overlay identity mismatch: ${overlay}. Hydrate the pinned "
            "darling-swift dependency with git lfs pull --include=libswiftFoundation.dylib. "
            "For an intentional dependency update, review and update this artifact manifest "
            "from its tracked LFS source metadata.")
    endif()
endfunction()
