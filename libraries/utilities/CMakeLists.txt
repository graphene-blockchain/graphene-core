list( APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/libraries/fc/GitVersionGen" )
include( GetGitRevisionDescription )
get_git_head_revision(GIT_REFSPEC GRAPHENE_GIT_REVISION_SHA)
# get_git_head_revision() reads the ref file itself and returns the ref name instead of the
# hash once git has packed that ref. It is still needed: it makes CMake re-run when HEAD
# moves. The hash itself comes from git.
find_package(Git QUIET)
if(GIT_FOUND)
    execute_process(COMMAND "${GIT_EXECUTABLE}" rev-parse HEAD
                    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                    RESULT_VARIABLE GIT_REV_PARSE_RESULT
                    OUTPUT_VARIABLE GIT_REV_PARSE_SHA
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    ERROR_QUIET)
    if(GIT_REV_PARSE_RESULT EQUAL 0)
        set(GRAPHENE_GIT_REVISION_SHA "${GIT_REV_PARSE_SHA}")
    endif()
endif()
get_git_unix_timestamp(GRAPHENE_GIT_REVISION_UNIX_TIMESTAMP)
# The build string is the release version plus the abbreviated commit hash, e.g.
# 1.2.0-19944518. Without git (a source archive) it is the bare version.
if(GRAPHENE_GIT_REVISION_SHA MATCHES "^[0-9a-f]+$")
    string(SUBSTRING "${GRAPHENE_GIT_REVISION_SHA}" 0 8 GRAPHENE_GIT_REVISION_SHORT_SHA)
    set(GRAPHENE_GIT_REVISION_DESCRIPTION "${GRAPHENE_VERSION}-${GRAPHENE_GIT_REVISION_SHORT_SHA}")
else()
    set(GRAPHENE_GIT_REVISION_DESCRIPTION "${GRAPHENE_VERSION}")
endif()

file(GLOB HEADERS "include/graphene/utilities/*.hpp")

set(sources
   key_conversion.cpp
   string_escape.cpp
   tempdir.cpp
   words.cpp
   elasticsearch.cpp
   ${HEADERS})

configure_file("${CMAKE_CURRENT_SOURCE_DIR}/git_revision.cpp.in" "${CMAKE_CURRENT_BINARY_DIR}/git_revision.cpp" @ONLY)
list(APPEND sources "${CMAKE_CURRENT_BINARY_DIR}/git_revision.cpp")

find_curl()

include_directories(${CURL_INCLUDE_DIRS})
add_library( graphene_utilities
             ${sources}
             ${HEADERS} )
if(CURL_STATICLIB)
  SET_TARGET_PROPERTIES(graphene_utilities PROPERTIES
  COMPILE_DEFINITIONS "CURL_STATICLIB")
endif(CURL_STATICLIB)
target_link_libraries( graphene_utilities fc ${CURL_LIBRARIES})
target_include_directories( graphene_utilities
                            PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include" )
if (USE_PCH)
  set_target_properties(graphene_utilities PROPERTIES COTIRE_ADD_UNITY_BUILD FALSE)
  cotire(graphene_utilities)
endif(USE_PCH)

install( TARGETS
   graphene_utilities

   RUNTIME DESTINATION bin
   LIBRARY DESTINATION lib
   ARCHIVE DESTINATION lib
)
install( FILES ${HEADERS} DESTINATION "include/graphene/utilities" )
