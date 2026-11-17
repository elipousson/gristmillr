# Confirm a destructive action. Interactive sessions are prompted; scripts
# must opt in with `confirm = TRUE`. `label` may be a function so that the name
# is only looked up (one request) when a prompt is needed.
confirm_delete <- function(
  kind,
  label,
  mode,
  confirm,
  call = caller_env(),
  verb = "delete"
) {
  if (isTRUE(confirm)) {
    return(invisible(TRUE))
  }
  if (!is.null(confirm) && !isFALSE(confirm)) {
    cli::cli_abort(
      "{.arg confirm} must be `TRUE`, `FALSE` or `NULL`, not {.obj_type_friendly {confirm}}.",
      call = call
    )
  }

  if (isFALSE(confirm) || !is_interactive()) {
    cli::cli_abort(
      c(
        "Must confirm before {verb_ing(verb)} a {kind}.",
        i = "Use {.code confirm = TRUE} to {verb} without a prompt."
      ),
      class = "gristmillr_confirm_required",
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
