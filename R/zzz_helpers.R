#' @keywords internal
#' @noRd
#'
#' @title Extract Speeches from Congressional Record Text
#'
#' @description
#' Parses raw congressional record text to identify individual speaker segments
#' based on a regular expression. Returns a list of speeches, each containing
#' the speaker's name and associated text.
#'
#' @param text Character string. The full text of the congressional record page to parse.
#'
#'
#' @return
#' A list of lists, where each sublist contains a `speaker` and their corresponding `text`.
#'
#' @importFrom stringr str_locate_all
#' @importFrom stringr regex
#' @importFrom stringr str_sub
#' @importFrom stringr str_remove
scrape_speeches <- function(text) {

  speaker_regex <- "^  +(M(?:r|rs|s)\\.|Chairman|Chairwoman|Dr\\.)\\s[A-Z]{2,}(\\s[A-Z]{2,})*(\\sof\\s[A-Z][a-zA-Z]+(\\s[A-Z][a-zA-Z]+)*)?(\\s\\[continuing\\])?\\."

  matches <- str_locate_all(text, regex(speaker_regex, multiline = TRUE))[[1]]
  speeches <- list()
  if (nrow(matches) == 0) return(speeches)

  current_speaker <- NULL
  speech_start <- NULL

  for (i in seq_len(nrow(matches))) {
    name_start <- matches[i, 1]
    name_end <- matches[i, 2]

    if (!is.null(current_speaker)) {
      speech_end <- name_start - 1
      speech_text <- str_sub(text, speech_start, speech_end)
      speeches <- append(speeches, list(list(speaker = current_speaker, text = speech_text)))
    }

    current_speaker <- str_sub(text, name_start, name_end)
    current_speaker <- str_remove(current_speaker, "\\.$")
    speech_start <- name_end + 1
  }

  if (!is.null(current_speaker)) {
    speech_text <- str_sub(text, speech_start, nchar(text))
    speeches <- append(speeches, list(list(speaker = current_speaker, text = speech_text)))
  }

  return(speeches)
}


#' @keywords internal
#' @noRd
#'
#' @title Retrieve Search Results from the API
#'
#' @description
#' Sends a POST request to the API search endpoint with a specified query and optional
#' pagination controls. Returns parsed search results sorted by date issued (descending).
#'
#' @param API_KEY Character string. Your API key for accessing the govinfo API.
#' @param BASE_API_URL Character string. Base URL for the API (e.g., "https://api.govinfo.gov").
#' @param query Character string. Search query term(s) to use.
#' @param page_size Integer. Number of results per page (default is 1000).
#' @param offset_mark Character string. Pagination offset mark (default is "*").
#'
#' @return
#' A parsed list object containing the search results.
#'
#' @importFrom httr POST
#' @importFrom httr content_type_json
#' @importFrom httr accept_json
#' @importFrom httr stop_for_status
#' @importFrom httr content
get_search_results <- function(API_KEY, BASE_API_URL, query, page_size = 1000, offset_mark = "*") {
  url <- paste0(BASE_API_URL, "/search")
  payload <- list(
    query = query,
    pageSize = page_size,
    offsetMark = offset_mark,
    sorts = list(list(field = "dateIssued", sortOrder = "DESC")),
    resultLevel = "default"
  )

  response <- POST(
    url,
    query = list(api_key = API_KEY, historical = TRUE),
    body = payload,
    encode = "json",
    content_type_json(),
    accept_json()
  )

  stop_for_status(response)
  return(content(response, as = "parsed"))
}


#' @keywords internal
#' @noRd
#'
#' @title Retrieve All Granules for a Package
#'
#' @description
#' Fetches all granules associated with a given package ID by repeatedly querying
#' the API using pagination (via `offsetMark`). Collects all granules into a single list.
#'
#' @param API_KEY Character string. Your API key for accessing the govinfo API.
#' @param BASE_API_URL Character string. Base URL for the API (e.g., "https://api.govinfo.gov").
#' @param package_id Character string. The package ID identifying the document collection.
#'
#' @return
#' A list containing all granule metadata entries retrieved for the specified package.
#'
#' @importFrom httr GET
#' @importFrom httr stop_for_status
#' @importFrom httr content
get_granules <- function(API_KEY, BASE_API_URL, package_id) {
  url <- paste0(BASE_API_URL, "/packages/", package_id, "/granules")
  granules <- list()
  offset_mark <- "*"

  repeat {
    params <- list(api_key = API_KEY, pageSize = 1000, offsetMark = offset_mark)

    response <- GET(url, query = params)
    stop_for_status(response)
    data <- content(response, as = "parsed")

    if (!is.null(data$granules)) {
      granules <- c(granules, data$granules)
    }

    if (!is.null(data$nextOffsetMark)) {
      offset_mark <- data$nextOffsetMark
    } else {
      break
    }
  }

  return(granules)
}


#' @keywords internal
#' @noRd
#'
#' @title Retrieve Granule Summary Metadata
#'
#' @description
#' Constructs the API request URL for a given package and granule ID,
#' sends a GET request to retrieve the granule's summary metadata,
#' and parses the content if successful.
#'
#' @param API_KEY Character string. Your API key for accessing the govinfo API.
#' @param BASE_API_URL Character string. Base URL for the API (e.g., "https://api.govinfo.gov").
#' @param package_id Character string. The package ID identifying the document collection.
#' @param granule_id Character string. The specific granule ID within the package.
#'
#' @return
#' A parsed list object containing the granule summary metadata if successful; otherwise `NULL`.
#'
#' @importFrom httr GET
#' @importFrom httr status_code
#' @importFrom httr content
get_granule_summary <- function(API_KEY, BASE_API_URL, package_id, granule_id) {
  url <- paste0(BASE_API_URL, "/packages/", package_id, "/granules/", granule_id, "/summary")
  response <- GET(url, query = list(api_key = API_KEY))
  if (status_code(response) == 200) {
    return(content(response, as = "parsed"))
  } else {
    return(NULL)
  }
}


#' @keywords internal
#' @noRd
#'
#' @title Retrieve HTML Content for a Congressional Record Granule
#'
#' @description
#' Constructs the API request URL for a given package and granule ID,
#' sends a GET request to retrieve the HTML content, and returns the
#' HTML as a character string if successful.
#'
#' @param API_KEY Character string. Your API key for accessing the govinfo API.
#' @param BASE_API_URL Character string. Base URL for the API (e.g., "https://api.govinfo.gov").
#' @param package_id Character string. The package ID identifying the document collection.
#' @param granule_id Character string. The specific granule ID within the package.
#'
#' @return
#' A character string containing the HTML content if successful; otherwise `NULL`.
#'
#' @importFrom httr GET
#' @importFrom httr status_code
#' @importFrom httr content
get_htm_content <- function(API_KEY, BASE_API_URL, package_id, granule_id) {
  url <- paste0(BASE_API_URL, "/packages/", package_id, "/granules/", granule_id, "/htm")
  response <- GET(url, query = list(api_key = API_KEY))
  if (status_code(response) == 200) {
    return(content(response, as = "text"))
  } else {
    return(NULL)
  }
}


#' @keywords internal
#' @noRd
#'
#' @title Process Congressional Speech Text
#'
#' @description
#' Parses the HTML content of a congressional record page, extracts the speech text,
#' processes it into individual speaker segments, and formats it with metadata
#' (URL, date, title, speaker, cleaned text).
#'
#' @param API_KEY Character string. Your API key for accessing the govinfo API.
#' @param record_url Character string. URL of the record.
#' @param record_date Character string or Date. Date of the record.
#' @param record_title Character string. Title of the record.
#' @param htm_content Raw HTML content as a character string.
#'
#' @return
#' A list of lists, where each sublist contains the URL, date, title, speaker,
#' and cleaned speech text for an individual speech.
#'
#' @importFrom rvest read_html
#' @importFrom rvest html_node
#' @importFrom rvest html_text
#' @importFrom stringr str_replace_all
#' @importFrom stringr str_squish
process_speech <- function(API_KEY, record_url, record_date, record_title, htm_content) {
  page <- read_html(htm_content, options = "HUGE")
  pre_node <- html_node(page, "pre")

  if (is.null(pre_node)) {
    return(list())
  }

  record_text <- html_text(pre_node)
  speeches <- scrape_speeches(record_text)

  lapply(speeches, function(speech) {
    list(
      url = record_url,
      date = record_date,
      title = record_title,
      speaker = speech$speaker,
      text = str_squish(str_replace_all(speech$text, "[\n\t]", " "))
    )
  })
}
