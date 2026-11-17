#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @import rlang
#' @importFrom S7 new_class new_object S7_object new_generic method method<-
#' @importFrom S7 class_character class_logical class_numeric class_integer
#' @importFrom S7 class_function class_any prop
## usethis namespace: end
NULL

.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}

# Make `@` available on R < 4.3
#' @rawNamespace if (getRversion() < "4.3.0") importFrom("S7", "@")
NULL
