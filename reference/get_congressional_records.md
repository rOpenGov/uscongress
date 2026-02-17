# Retrieve and Process Congressional Record Speeches

Queries the Congressional Record collection for a given session and date
range, retrieves speech text and associated metadata from granules, and
processes the information into a structured tibble. Supports limiting
the number of speeches collected.

## Usage

``` r
get_congressional_records(
  API_KEY,
  max_results = NULL,
  date_from = NULL,
  date_to = NULL,
  congress_session = 117
)
```

## Arguments

- API_KEY:

  Character string. Your API key for accessing the govinfo API.

- max_results:

  Integer (optional). Maximum number of speeches to retrieve. If
  \`NULL\`, retrieves all available speeches.

- date_from:

  Character string (optional). Start date (YYYY-MM-DD) for filtering
  records. If \`NULL\`, determined by session.

- date_to:

  Character string (optional). End date (YYYY-MM-DD) for filtering
  records. If \`NULL\`, determined by session.

- congress_session:

  Integer. Congressional session number (default is 117).

## Value

A tibble where each row corresponds to an extracted speech, including
columns for URL, date, title, speaker, and speech text.

## Examples

``` r
if (nzchar(Sys.getenv("GOVINFO_API_KEY"))) {
  # Retrieve your govinfo API key from environment
  api_key <- Sys.getenv("GOVINFO_API_KEY")

  # Retrieve Congressional Record speeches from the 117th Congress (2021-2023)
  speeches <- get_congressional_records(
    API_KEY = api_key,
    max_results = 5,
    congress_session = 117
  )
  head(speeches)
}
```
