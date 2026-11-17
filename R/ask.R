# Gate a destructive action. `ask = NULL` (the default) and `ask = TRUE` prompt
# in an interactive session and refuse to run in a script; `ask = FALSE` skips
# the prompt. `label` may be a function so that the name is only looked up (one
# request) when a prompt is needed.
check_ask <- function(
  kind,
  label,
  mode,
  ask,
  call = caller_env(),
  verb = "delete"
) {
  if (isFALSE(ask)) {
    return(invisible(TRUE))
  }
  if (!is.null(ask) && !isTRUE(ask)) {
    cli::cli_abort(
      "{.arg ask} must be `TRUE`, `FALSE` or `NULL`, not {.obj_type_friendly {ask}}.",
      call = call
    )
  }

  if (!is_interactive()) {
    cli::cli_abort(
      c(
        "Can't ask before {verb_ing(verb)} a {kind} in a non-interactive session.",
        i = "Use {.code ask = FALSE} to {verb} without a prompt."
      ),
      class = "gristmillr_ask_required",
      call = call
    )
  }

  if (is.function(label)) {
    label <- label()
  }

  if (mode == "trash") {
    ok <- isTRUE(ask_yes_no(
      sprintf("Move %s \"%s\" to the trash?", kind, label)
    ))
  } else if (mode == "replace") {
    ok <- isTRUE(ask_yes_no(
      sprintf(
        "Replace the current contents of the %s \"%s\"? This can't be undone.",
        kind,
        label
      )
    ))
  } else if (mode == "delete") {
    # Deletion with no trash to restore from, but not worth typing a name.
    ok <- isTRUE(ask_yes_no(
      sprintf("Delete %s \"%s\"? This can't be undone.", kind, label)
    ))
  } else {
    answer <- ask_text(
      sprintf(
        "This permanently deletes %s \"%s\" and can't be undone.\nType its name to confirm: ",
        kind,
        label
      )
    )
    ok <- identical(answer, label)
  }

  if (!ok) {
    cli::cli_abort(
      "Cancelled.",
      class = "gristmillr_cancelled",
      call = call
    )
  }
  invisible(TRUE)
}

verb_ing <- function(verb) {
  paste0(sub("e$", "", verb), "ing")
}

ask_yes_no <- function(msg) {
  utils::askYesNo(msg, default = FALSE)
}

ask_text <- function(msg) {
  readline(msg)
}
