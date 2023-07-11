set(PACKAGE_VERSION "1.2.13")
if (PACKAGE_VERSION VERSION_EQUAL PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_EXACT  TRUE)
endif()
if (PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_UNSUITABLE  TRUE)
else()
    set(PACKAGE_VERSION_COMPATIBLE  TRUE)
endif()
