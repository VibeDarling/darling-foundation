# Artifact identity from darling-swift 0289238b54b79f13c2e49908c52302e58d748a1a,
# tracked libswiftFoundation.dylib LFS pointer. Update with that pinned source metadata.
function(foundation_validate_swift_overlay overlay)
    set(expected_sha256 "aebf3c00041c5e27b2a8620b4f8fa840fc5af2edb109b356a546c5596d083b98")
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
