# gristmillr

gristmillr is an [httr2](https://httr2.r-lib.org/)-based client for the
[Grist](https://www.getgrist.com/) REST API. Functions take a lightweight
document handle first and return data frames, so they compose with pipes.

This is a development version. It is not yet validated against a live Grist
server; see `NEWS.md`.

## Setup

Set your API key (and, for a team or self-hosted site, the server) in
`.Renviron`:

```
GRIST_API_KEY=<your key>
GRIST_SERVER=https://myteam.getgrist.com
```

## Usage

```r
library(gristmillr)

doc <- grist_doc("<doc id or URL>")

grist_tables(doc)

doc |>
  grist_records("People", filter = list(status = "active"), sort = "-age")

doc |>
  grist_records_add("People", data.frame(name = "Ann", age = 30L))
```
