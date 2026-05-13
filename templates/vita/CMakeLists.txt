cmake_minimum_required(VERSION 3.16)

if(NOT DEFINED CMAKE_TOOLCHAIN_FILE)
  if(DEFINED ENV{VITASDK})
    set(CMAKE_TOOLCHAIN_FILE "$ENV{VITASDK}/share/vita.toolchain.cmake" CACHE PATH "toolchain file")
  else()
    message(FATAL_ERROR "Please define VITASDK to point to your SDK path!")
  endif()
endif()

project([LIME_PROJECT_FILENAME])

include("${VITASDK}/share/vita.cmake" REQUIRED)

set(VITA_APP_NAME    "[LIME_PROJECT_TITLE]")
set(VITA_TITLEID     "[LIME_PROJECT_TITLEID]")
set(VITA_VERSION     "[LIME_PROJECT_VERSION]")

set(STUB_SRC "${CMAKE_BINARY_DIR}/_vita_stub.cpp")
file(WRITE "${STUB_SRC}"
"extern \"C\" int lime_register_prims();\n"
"extern \"C\" void __hxcpp_lib_main();\n"
"\n"
"int main(int argc, char **argv) {\n"
"    lime_register_prims();\n"
"    __hxcpp_lib_main();\n"
"    return 0;\n"
"}\n"
)

add_executable(${PROJECT_NAME} ${STUB_SRC})

target_compile_options(${PROJECT_NAME} PRIVATE
    -mthumb-interwork
    -O2
)
target_link_options(${PROJECT_NAME} PRIVATE
    -mthumb-interwork
    -Wl,--fix-cortex-a8
    -Wl,-Map=${PROJECT_NAME}.map
)

target_link_libraries(${PROJECT_NAME}
    -Wl,--start-group
    -Wl,--whole-archive
    [HAXE_MAIN_LIB]
    [LIME_MAIN_DIR]/lib/liblime.a
    -Wl,--no-whole-archive
    SDL2
    SDL2main
    vitaGL
    mathneon
    vitashark
    SceShaccCgExt
    taihen_stub
    SceShaccCg_stub
    SceKernelDmacMgr_stub
    SceLibKernel_stub
    SceGxm_stub
    SceDisplay_stub
    SceCtrl_stub
    ScePower_stub
    SceAudio_stub
    SceAudioIn_stub
    SceHid_stub
    SceMotion_stub
    SceTouch_stub
    SceCommonDialog_stub
    SceAppMgr_stub
    SceAppUtil_stub
    SceNet_stub
    SceNetCtl_stub
    SceHttp_stub
    SceSsl_stub
    SceSysmodule_stub
    SceKernelThreadMgr_stub
    vorbisfile
    vorbis
    ogg
    openal
    png
    jpeg
    freetype
    harfbuzz
    z
    lzma
    stdc++
    m
    c
    -Wl,--end-group
    pthread
)

vita_create_self(${PROJECT_NAME}.self ${PROJECT_NAME})

vita_create_vpk(${PROJECT_NAME}.vpk ${VITA_TITLEID} ${PROJECT_NAME}.self
    VERSION ${VITA_VERSION}
    NAME    ${VITA_APP_NAME}
    FILE    [VITA_DATA_DIR] sce_sys
    FILE    [OUT_DIR]/VITA_ASSETS/assets assets
    FILE    [OUT_DIR]/manifest manifest
)

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE:${PROJECT_NAME}>"
        "[OUT_DIR]/$<TARGET_FILE_NAME:${PROJECT_NAME}>"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.map"
        "[OUT_DIR]/${PROJECT_NAME}.map"
)

add_custom_command(TARGET ${PROJECT_NAME}.self-self POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "[OUT_DIR]"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.self"
        "[OUT_DIR]/${PROJECT_NAME}.self"
)

add_custom_command(TARGET ${PROJECT_NAME}.vpk-vpk POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "[OUT_DIR]"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_BINARY_DIR}/${PROJECT_NAME}.vpk"
        "[OUT_DIR]/${PROJECT_NAME}.vpk"
)
