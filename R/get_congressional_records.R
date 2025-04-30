#' Retrieve and Process Congressional Record Speeches
#'
#' @description
#' Queries the Congressional Record collection for a given session and date range,
#' retrieves speech text and associated metadata from granules, and processes the
#' information into a structured tibble. Supports limiting the number of speeches collected.
#'
#' @param API_KEY Character string. Your API key for accessing the govinfo API.
#' @param max_results Integer (optional). Maximum number of speeches to retrieve. If `NULL`, retrieves all available speeches.
#' @param date_from Character string (optional). Start date (YYYY-MM-DD) for filtering records. If `NULL`, determined by session.
#' @param date_to Character string (optional). End date (YYYY-MM-DD) for filtering records. If `NULL`, determined by session.
#' @param congress_session Integer. Congressional session number (default is 117).
#'
#' @return
#' A tibble where each row corresponds to an extracted speech, including columns for
#' URL, date, title, speaker, and speech text.
#'
#' @importFrom stringr str_squish
#' @importFrom dplyr bind_rows
#' @importFrom tibble as_tibble
#'
#' @examples
#' if (nzchar(Sys.getenv("GOVINFO_API_KEY"))) {
#'   # Retrieve your govinfo API key from environment
#'   api_key <- Sys.getenv("GOVINFO_API_KEY")
#'
#'   # Retrieve Congressional Record speeches from the 117th Congress (2021-2023)
#'   speeches <- get_congressional_records(
#'     API_KEY = api_key,
#'     max_results = 5,
#'     congress_session = 117
#'   )
#'   head(speeches)
#' }
#'
#' @export
#'
get_congressional_records <- function(API_KEY,
                                      max_results = NULL,
                                      date_from = NULL,
                                      date_to = NULL,
                                      congress_session = 117) {

  congress_session_dates <- list(
    `118` = list(start = "2023-01-03", end = "2025-01-03"),
    `117` = list(start = "2021-01-03", end = "2023-01-03"),
    `116` = list(start = "2019-01-03", end = "2021-01-03"),
    `115` = list(start = "2017-01-03", end = "2019-01-03"),
    `114` = list(start = "2015-01-06", end = "2017-01-03"),
    `113` = list(start = "2013-01-03", end = "2015-01-03"),
    `112` = list(start = "2011-01-03", end = "2013-01-03"),
    `111` = list(start = "2009-01-06", end = "2011-01-03"),
    `110` = list(start = "2007-01-04", end = "2009-01-03"),
    `109` = list(start = "2005-01-04", end = "2007-01-03"),
    `108` = list(start = "2003-01-07", end = "2005-01-03"),
    `107` = list(start = "2001-01-03", end = "2003-01-03"),
    `106` = list(start = "1999-01-06", end = "2001-01-03"),
    `105` = list(start = "1997-01-07", end = "1999-01-03"),
    `104` = list(start = "1995-01-04", end = "1997-01-03")
  )

  BASE_API_URL <- "https://api.govinfo.gov"

  # Set dates automatically if not provided
  session_key <- as.character(congress_session)
  if ((is.null(date_from) || is.null(date_to)) && session_key %in% names(congress_session_dates)) {
    date_from <- congress_session_dates[[session_key]]$start
    date_to <- congress_session_dates[[session_key]]$end
    message("Using session ", congress_session, " dates: ", date_from, " to ", date_to)
  } else if (is.null(date_from) || is.null(date_to)) {
    stop("Unknown or unsupported congressional session. Please specify date_from and date_to manually.")
  }

  # Build query
  base_query <- paste0("collection:CREC AND docClass:CREC AND congress:", congress_session,
                       " AND (section:House OR section:Senate)")
  query <- paste0(base_query, " AND dateIssued:[", date_from, " TO ", date_to, "]")

  offset_mark <- "*"
  total_speeches <- 0
  all_speeches <- list()

  repeat {
    search_data <- get_search_results(API_KEY, BASE_API_URL, query, page_size=1000, offset_mark)
    results <- search_data$results
    if (length(results) == 0) break

    for (result in results) {
      package_id <- result$packageId
      if (is.null(package_id)) next

      granules <- get_granules(API_KEY, BASE_API_URL, package_id)

      for (granule in granules) {
        granule_id <- granule$granuleId
        if (is.null(granule_id)) next

        summary <- get_granule_summary(API_KEY, BASE_API_URL, package_id, granule_id)
        if (is.null(summary)) next

        record_title <- str_squish(summary$title)
        record_date <- summary$dateIssued

        htm_content <- get_htm_content(API_KEY, BASE_API_URL, package_id, granule_id)
        if (is.null(htm_content)) next

        record_url <- paste0(BASE_API_URL, "/packages/", package_id, "/granules/", granule_id, "/htm")

        speeches <- process_speech(API_KEY, record_url, record_date, record_title, htm_content)

        for (speech in speeches) {
          all_speeches <- c(all_speeches, list(speech))
          total_speeches <- total_speeches + 1

          # Progress print
          message("Collected ", total_speeches, " speeches. Package: ", package_id, " Granule: ", granule_id)

          if (!is.null(max_results) && total_speeches >= max_results) {
            message("Scraping complete. Total speeches: ", total_speeches)
            df <- bind_rows(lapply(all_speeches, as_tibble))
            return(df)
          }
        }
      }
    }

    if (!is.null(search_data$nextOffsetMark)) {
      offset_mark <- search_data$nextOffsetMark
    } else {
      break
    }
  }

  message("Scraping complete. Total speeches: ", total_speeches)
  df <- bind_rows(lapply(all_speeches, as_tibble))
  return(df)
}


