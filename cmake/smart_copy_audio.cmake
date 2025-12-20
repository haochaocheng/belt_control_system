# Smart copy AUDIO folder - inline implementation
# Directly implements smart copy logic without external include

cmake_minimum_required(VERSION 3.16)

set(SOURCE_DIR "${CMAKE_SOURCE_DIR}/AUDIO")
set(DEST_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/AUDIO")
set(LABEL "AUDIO files")

# Inline smart copy logic
if(NOT DEFINED SOURCE_DIR OR NOT DEFINED DEST_DIR)
    message(FATAL_ERROR "SOURCE_DIR and DEST_DIR must be defined")
endif()

message(STATUS "Smart copying ${LABEL}...")

# Check if source exists
if(NOT EXISTS "${SOURCE_DIR}")
    message(WARNING "Source directory not found: ${SOURCE_DIR}")
    return()
endif()

# Create destination if needed
if(NOT EXISTS "${DEST_DIR}")
    message(STATUS "Creating directory: ${DEST_DIR}")
    file(MAKE_DIRECTORY "${DEST_DIR}")
endif()

# Get all files from source
file(GLOB_RECURSE SOURCE_FILES
    RELATIVE "${SOURCE_DIR}"
    "${SOURCE_DIR}/*"
)

set(COPIED_COUNT 0)
set(SKIPPED_COUNT 0)
set(TOTAL_COUNT 0)

foreach(REL_FILE ${SOURCE_FILES})
    set(SRC_FILE "${SOURCE_DIR}/${REL_FILE}")
    set(DEST_FILE "${DEST_DIR}/${REL_FILE}")

    math(EXPR TOTAL_COUNT "${TOTAL_COUNT} + 1")

    set(NEED_COPY FALSE)

    # Check if destination file exists
    if(NOT EXISTS "${DEST_FILE}")
        set(NEED_COPY TRUE)
    else()
        # Compare file timestamps
        file(TIMESTAMP "${SRC_FILE}" SRC_TIME "%s")
        file(TIMESTAMP "${DEST_FILE}" DEST_TIME "%s")

        if("${SRC_TIME}" STREQUAL "")
            # Fallback: compare file sizes
            file(SIZE "${SRC_FILE}" SRC_SIZE)
            file(SIZE "${DEST_FILE}" DEST_SIZE)

            if(NOT "${SRC_SIZE}" EQUAL "${DEST_SIZE}")
                set(NEED_COPY TRUE)
            endif()
        elseif("${SRC_TIME}" GREATER "${DEST_TIME}")
            set(NEED_COPY TRUE)
        endif()
    endif()

    if(NEED_COPY)
        # Get destination directory
        get_filename_component(DEST_SUBDIR "${DEST_FILE}" DIRECTORY)

        # Create subdirectory if needed
        if(NOT EXISTS "${DEST_SUBDIR}")
            file(MAKE_DIRECTORY "${DEST_SUBDIR}")
        endif()

        # Copy file
        file(COPY_FILE "${SRC_FILE}" "${DEST_FILE}")
        math(EXPR COPIED_COUNT "${COPIED_COUNT} + 1")
    else()
        math(EXPR SKIPPED_COUNT "${SKIPPED_COUNT} + 1")
    endif()
endforeach()

message(STATUS "${LABEL}: ${COPIED_COUNT} copied, ${SKIPPED_COUNT} skipped (${TOTAL_COUNT} total)")
