# grist_webhook_create() validates input

    Code
      grist_webhook_create(test_doc(), "https://example.com", "T", event_types = "delete")
    Condition
      Error in `grist_webhook_create()`:
      ! `event_types` must be one of "add" or "update", not "delete".

---

    Code
      grist_webhook_create(test_doc(), 1, "T")
    Condition
      Error in `grist_webhook_create()`:
      ! `url` must be a single string, not the number 1.

# grist_webhook_update() needs something to change

    Code
      grist_webhook_update(test_doc(), "w1")
    Condition
      Error in `grist_webhook_update()`:
      ! Must supply at least one setting to change.

# declining the prompt or an unknown ID deletes nothing

    Code
      grist_webhook_delete(test_doc(), "nope")
    Condition
      Error in `grist_webhook_delete()`:
      ! Can't find a webhook with ID "nope".

