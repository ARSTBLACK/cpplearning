include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(cpplearning_supports_sanitizers)
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

macro(cpplearning_setup_options)
  option(cpplearning_ENABLE_HARDENING "Enable hardening" ON)
  option(cpplearning_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    cpplearning_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    cpplearning_ENABLE_HARDENING
    OFF)

  cpplearning_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR cpplearning_PACKAGING_MAINTAINER_MODE)
    option(cpplearning_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(cpplearning_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(cpplearning_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cpplearning_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(cpplearning_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cpplearning_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(cpplearning_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cpplearning_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cpplearning_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cpplearning_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(cpplearning_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(cpplearning_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cpplearning_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(cpplearning_ENABLE_IPO "Enable IPO/LTO" ON)
    option(cpplearning_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(cpplearning_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(cpplearning_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(cpplearning_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(cpplearning_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(cpplearning_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(cpplearning_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(cpplearning_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(cpplearning_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(cpplearning_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(cpplearning_ENABLE_PCH "Enable precompiled headers" OFF)
    option(cpplearning_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      cpplearning_ENABLE_IPO
      cpplearning_WARNINGS_AS_ERRORS
      cpplearning_ENABLE_USER_LINKER
      cpplearning_ENABLE_SANITIZER_ADDRESS
      cpplearning_ENABLE_SANITIZER_LEAK
      cpplearning_ENABLE_SANITIZER_UNDEFINED
      cpplearning_ENABLE_SANITIZER_THREAD
      cpplearning_ENABLE_SANITIZER_MEMORY
      cpplearning_ENABLE_UNITY_BUILD
      cpplearning_ENABLE_CLANG_TIDY
      cpplearning_ENABLE_CPPCHECK
      cpplearning_ENABLE_COVERAGE
      cpplearning_ENABLE_PCH
      cpplearning_ENABLE_CACHE)
  endif()

  cpplearning_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (cpplearning_ENABLE_SANITIZER_ADDRESS OR cpplearning_ENABLE_SANITIZER_THREAD OR cpplearning_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(cpplearning_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(cpplearning_global_options)
  if(cpplearning_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    cpplearning_enable_ipo()
  endif()

  cpplearning_supports_sanitizers()

  if(cpplearning_ENABLE_HARDENING AND cpplearning_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cpplearning_ENABLE_SANITIZER_UNDEFINED
       OR cpplearning_ENABLE_SANITIZER_ADDRESS
       OR cpplearning_ENABLE_SANITIZER_THREAD
       OR cpplearning_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${cpplearning_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${cpplearning_ENABLE_SANITIZER_UNDEFINED}")
    cpplearning_enable_hardening(cpplearning_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(cpplearning_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(cpplearning_warnings INTERFACE)
  add_library(cpplearning_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  cpplearning_set_project_warnings(
    cpplearning_warnings
    ${cpplearning_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(cpplearning_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    cpplearning_configure_linker(cpplearning_options)
  endif()

  include(cmake/Sanitizers.cmake)
  cpplearning_enable_sanitizers(
    cpplearning_options
    ${cpplearning_ENABLE_SANITIZER_ADDRESS}
    ${cpplearning_ENABLE_SANITIZER_LEAK}
    ${cpplearning_ENABLE_SANITIZER_UNDEFINED}
    ${cpplearning_ENABLE_SANITIZER_THREAD}
    ${cpplearning_ENABLE_SANITIZER_MEMORY})

  set_target_properties(cpplearning_options PROPERTIES UNITY_BUILD ${cpplearning_ENABLE_UNITY_BUILD})

  if(cpplearning_ENABLE_PCH)
    target_precompile_headers(
      cpplearning_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(cpplearning_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    cpplearning_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(cpplearning_ENABLE_CLANG_TIDY)
    cpplearning_enable_clang_tidy(cpplearning_options ${cpplearning_WARNINGS_AS_ERRORS})
  endif()

  if(cpplearning_ENABLE_CPPCHECK)
    cpplearning_enable_cppcheck(${cpplearning_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(cpplearning_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    cpplearning_enable_coverage(cpplearning_options)
  endif()

  if(cpplearning_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(cpplearning_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(cpplearning_ENABLE_HARDENING AND NOT cpplearning_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR cpplearning_ENABLE_SANITIZER_UNDEFINED
       OR cpplearning_ENABLE_SANITIZER_ADDRESS
       OR cpplearning_ENABLE_SANITIZER_THREAD
       OR cpplearning_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    cpplearning_enable_hardening(cpplearning_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
