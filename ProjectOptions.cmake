include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(urban_pancake_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(urban_pancake_setup_options)
  option(urban_pancake_ENABLE_HARDENING "Enable hardening" ON)
  option(urban_pancake_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    urban_pancake_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    urban_pancake_ENABLE_HARDENING
    OFF)

  urban_pancake_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR urban_pancake_PACKAGING_MAINTAINER_MODE)
    option(urban_pancake_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(urban_pancake_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(urban_pancake_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(urban_pancake_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(urban_pancake_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(urban_pancake_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(urban_pancake_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(urban_pancake_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(urban_pancake_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(urban_pancake_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(urban_pancake_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(urban_pancake_ENABLE_PCH "Enable precompiled headers" OFF)
    option(urban_pancake_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(urban_pancake_ENABLE_IPO "Enable IPO/LTO" ON)
    option(urban_pancake_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(urban_pancake_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(urban_pancake_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(urban_pancake_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(urban_pancake_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(urban_pancake_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(urban_pancake_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(urban_pancake_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(urban_pancake_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(urban_pancake_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(urban_pancake_ENABLE_PCH "Enable precompiled headers" OFF)
    option(urban_pancake_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      urban_pancake_ENABLE_IPO
      urban_pancake_WARNINGS_AS_ERRORS
      urban_pancake_ENABLE_USER_LINKER
      urban_pancake_ENABLE_SANITIZER_ADDRESS
      urban_pancake_ENABLE_SANITIZER_LEAK
      urban_pancake_ENABLE_SANITIZER_UNDEFINED
      urban_pancake_ENABLE_SANITIZER_THREAD
      urban_pancake_ENABLE_SANITIZER_MEMORY
      urban_pancake_ENABLE_UNITY_BUILD
      urban_pancake_ENABLE_CLANG_TIDY
      urban_pancake_ENABLE_CPPCHECK
      urban_pancake_ENABLE_COVERAGE
      urban_pancake_ENABLE_PCH
      urban_pancake_ENABLE_CACHE)
  endif()

  urban_pancake_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (urban_pancake_ENABLE_SANITIZER_ADDRESS OR urban_pancake_ENABLE_SANITIZER_THREAD OR urban_pancake_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(urban_pancake_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(urban_pancake_global_options)
  if(urban_pancake_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    urban_pancake_enable_ipo()
  endif()

  urban_pancake_supports_sanitizers()

  if(urban_pancake_ENABLE_HARDENING AND urban_pancake_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR urban_pancake_ENABLE_SANITIZER_UNDEFINED
       OR urban_pancake_ENABLE_SANITIZER_ADDRESS
       OR urban_pancake_ENABLE_SANITIZER_THREAD
       OR urban_pancake_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${urban_pancake_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${urban_pancake_ENABLE_SANITIZER_UNDEFINED}")
    urban_pancake_enable_hardening(urban_pancake_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(urban_pancake_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(urban_pancake_warnings INTERFACE)
  add_library(urban_pancake_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  urban_pancake_set_project_warnings(
    urban_pancake_warnings
    ${urban_pancake_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(urban_pancake_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    urban_pancake_configure_linker(urban_pancake_options)
  endif()

  include(cmake/Sanitizers.cmake)
  urban_pancake_enable_sanitizers(
    urban_pancake_options
    ${urban_pancake_ENABLE_SANITIZER_ADDRESS}
    ${urban_pancake_ENABLE_SANITIZER_LEAK}
    ${urban_pancake_ENABLE_SANITIZER_UNDEFINED}
    ${urban_pancake_ENABLE_SANITIZER_THREAD}
    ${urban_pancake_ENABLE_SANITIZER_MEMORY})

  set_target_properties(urban_pancake_options PROPERTIES UNITY_BUILD ${urban_pancake_ENABLE_UNITY_BUILD})

  if(urban_pancake_ENABLE_PCH)
    target_precompile_headers(
      urban_pancake_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(urban_pancake_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    urban_pancake_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(urban_pancake_ENABLE_CLANG_TIDY)
    urban_pancake_enable_clang_tidy(urban_pancake_options ${urban_pancake_WARNINGS_AS_ERRORS})
  endif()

  if(urban_pancake_ENABLE_CPPCHECK)
    urban_pancake_enable_cppcheck(${urban_pancake_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(urban_pancake_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    urban_pancake_enable_coverage(urban_pancake_options)
  endif()

  if(urban_pancake_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(urban_pancake_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(urban_pancake_ENABLE_HARDENING AND NOT urban_pancake_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR urban_pancake_ENABLE_SANITIZER_UNDEFINED
       OR urban_pancake_ENABLE_SANITIZER_ADDRESS
       OR urban_pancake_ENABLE_SANITIZER_THREAD
       OR urban_pancake_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    urban_pancake_enable_hardening(urban_pancake_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
