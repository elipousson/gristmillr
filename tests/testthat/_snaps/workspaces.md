# org = 'current' errors helpfully when several orgs exist

    Code
      grist_workspaces(server = server)
    Condition
      Error in `grist_workspaces()`:
      ! Can't find the current org.
      i Set `org` to one of `grist_orgs()$id`.
      Caused by error in `grist_workspaces()`:
      ! Grist request failed with HTTP status 400.
      Caused by error in `httr2::req_perform()`:
      ! HTTP 400 Bad Request.
      i No organization chosen

