# uscongress

### `get_congressional_records()`

Retrieve and process Congressional Record speeches from the U.S. Government Publishing Office API.

## Description

This function queries the Congressional Record collection for a given congressional session and date range. It retrieves speeches from the House and Senate, processes associated metadata, and returns the results in a structured tibble. It supports optional limits on the number of speeches collected.

By default, if no `date_from` or `date_to` are specified, the function automatically sets the date range based on the congressional session provided.

The function fetches full speech content by retrieving and parsing associated granules from the GovInfo API.

## Usage

```r
get_congressional_records(API_KEY,
                           max_results = NULL,
                           date_from = NULL,
                           date_to = NULL,
                           congress_session = 117)
```

## Arguments

| Argument          | Type     | Description |
|-------------------|----------|-------------|
| `API_KEY`         | String   | Your GovInfo API key. Required to authenticate API requests. |
| `max_results`     | Integer  | Optional. Maximum number of speeches to retrieve. If `NULL`, retrieves all available speeches in the session and date range. |
| `date_from`       | String   | Optional. Start date (`"YYYY-MM-DD"`) for filtering speeches. If `NULL`, determined automatically by `congress_session`. |
| `date_to`         | String   | Optional. End date (`"YYYY-MM-DD"`) for filtering speeches. If `NULL`, determined automatically by `congress_session`. |
| `congress_session`| Integer  | Congressional session number (e.g., 117 for 2021–2023). Defaults to 117. |

## Details

- If `date_from` and `date_to` are omitted, the function uses preset start and end dates for sessions from the 104th (1995–1997) through the 118th (2023–2025) Congress.
- If an unsupported session is specified without dates, an error is raised.
- The function paginates through API results using the `nextOffsetMark` system.
- Each retrieved speech is cleaned, parsed, and formatted before inclusion in the final tibble.

The following helper functions are expected to be available and correctly implemented:

- `get_search_results()`
- `get_granules()`
- `get_granule_summary()`
- `get_htm_content()`
- `process_speech()`

## Return Value

A tibble (`data.frame`) where each row corresponds to a single speech, including:

- Speech text
- Speaker name
- Date
- Title of the record
- URL to the full record

## API Information

- **Base API Endpoint:** `https://api.govinfo.gov`
- **Collection Queried:** `CREC` (Congressional Record)
- **Sections Queried:** House and Senate
- **Documentation:** [GovInfo Developer Hub](https://api.govinfo.gov/docs/)

## Example

```r
speeches <- get_congressional_records(
  API_KEY = "your_api_key_here",
  max_results = 50,
  congress_session = 117
)

# View the first few speeches
head(speeches)
```

