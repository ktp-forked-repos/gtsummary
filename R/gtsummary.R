# https://stackoverflow.com/questions/9439256/how-can-i-handle-r-cmd-check-no-visible-binding-for-global-variable-notes-when#comment20826625_12429344
# 2012 hadley says "globalVariables is a hideous hack and I will never use it"
# 2014 hadley updates his own answer with globalVariables as one of "two solutions"
globalVariables(c('.', 'term', 'group', 'estimate', 'conf.high', 'conf.low', 'value'))

#' Beautiful, customizable summaries of statistical models
#'
#' @param models a single model object or a (potentially named) list of models
#' to summarize
#' @param fmt string which specifies how numeric values will be rounded. This
#' string is passed to the `sprintf` function. '\%.3f' will keep 3 digits after
#' the decimal point with trailing zero. '\%.5f' will keep 5 digits. '\%.3e' will
#' use exponential notation. See `?sprintf` for more options.
#' @param filename the file name to create on disk. Ensure that an extension
#' compatible with the output types is provided (`.html`, `.tex`, `.ltx`,
#' `.rtf`). Read `?gt::gtsave` for further details.
#' @param stars FALSE for no significance stars. TRUE for default significance
#' stars (*=.1, **=.05, ***=.01). Named numeric vector for custom significance
#' stars. For example, `c('*' = .1, '+' = .05)`
#' @param stars_note logical include a note at the bottom of the table to describe
#' the contents of the `stars` argument. The note will be omitted if `stars==NULL`
#' @param statistic string name of the statistic to include in parentheses
#' below estimates. Must be either "conf.int", or one of the column names
#' produced by the `broom::tidy` function. Typical values include: "std.error",
#' "conf.int", "statistic", "p.value".
#' @param statistic_override manually override the uncertainy estimates. This 
#' argument accepts three types of input:
#' \itemize{
#'   \item a function or list of functions of length(models) which produce variance-covariance matrices with row and column names equal to the names of your coefficient estimates. For example, `R` supplies the `vcov` function, and the `sandwich` package supplies `vcovHC`, `vcovHAC`, etc.
#'   \item a list of length(models) variance-covariance matrices with row and column names equal to the names of your coefficient estimates.
#'   \item a list of length(models) numeric vectors with names equal to the names of your coefficient estimates.
#' }
#' @param conf_level confidence level to use for confidence intervals
#' @param coef_map named character vector. Names refer to the original variable
#' names. Values refer to the variable names that will appear in the table.
#' Coefficients which are omitted from this vector will be omitted from the
#' table. The table will be ordered in the same order as this vector.
#' @param coef_omit string regular expression. Omits all matching coefficients
#' from the table (using `stringr::str_detect`).
#' @param gof_map data.frame with four columns: `raw`, `clean`, `fmt`, and
#' `omit`. See `gtsummary::gof_map`
#' @param gof_omit string regular expression. Omits all matching gof statistics from
#' the table (using `stringr::str_detect`).
#' @param add_rows list of character vectors, each of length equal to the number
#' of models + 1.
#' @param title string
#' @param subtitle string
#' @param notes list of notes to append to the bottom of the table.
#' @examples
#' \dontrun{
#' # load data and estimate models
#' data(trees)
#' models <- list()
#' models[['Bivariate']] <- lm(Girth ~ Height, data = trees)
#' models[['Multivariate']] <- lm(Girth ~ Height + Volume, data = trees)
#'
#' # simple table
#' gtsummary(models)
#'
#' # confidence intervals, p values, or t-stats instead of standard errors
#' gtsummary(models, statistic = 'conf.int', conf_level = 0.99)
#' gtsummary(models, statistic = 'p.value', conf_level = 0.99)
#' gtsummary(models, statistic = 'statistic', conf_level = 0.99)
#'
#' # rename and re-order coefficients
#' gtsummary(models, coef_map = c('Volume' = 'Large', 'Height' = 'Tall'))
#'
#' # save to file (html, rtf, or LaTeX)
#' gtsummary(models, filename = 'table.html')
#' gtsummary(models, filename = 'table.rtf')
#' gtsummary(models, filename = 'table.tex')
#'
#' # titles and subtitles
#' gtsummary(models, title = 'This is the title', subtitle = 'And a subtitle')
#'
#' # title with italicized text
#' gtsummary(models, title = gt::md('This is *the* title'))
#'
#' # notes at the bottom of the table (here, the second note includes markdown bold characters)
#' gtsummary(models, notes = list('A first note', gt::md('A **bold** note')))
#' }
#'
# see the README on github for a lot more examples: https://github.com/vincentarelbundock/gtsummary
#'
#' @export
gtsummary <- function(models,
                      statistic = 'std.error',
                      statistic_override = NULL,
                      conf_level = 0.95,
                      coef_map = NULL,
                      coef_omit = NULL,
                      gof_map = gtsummary::gof_map,
                      gof_omit = NULL,
                      fmt = '%.3f',
                      stars = FALSE,
                      stars_note = TRUE,
                      title = NULL,
                      subtitle = NULL,
                      notes = NULL,
                      add_rows = NULL,
                      filename = NULL) {

    # models must be a list of models or a single model
    if (!'list' %in% class(models)) {
        models <- list(models)
    }

    # check sanity of user input
    sanity_checks(models,
                  statistic = statistic,
                  statistic_override = statistic_override,
                  conf_level = conf_level,
                  coef_map = coef_map,
                  coef_omit = coef_omit,
                  gof_map = gof_map,
                  gof_omit = gof_omit,
                  fmt = fmt,
                  stars = stars,
                  stars_note = stars_note,
                  title = title,
                  subtitle = subtitle,
                  notes = notes,
                  add_rows = add_rows,
                  filename = filename)

    # stars
    if (is.logical(stars)) {
        if (stars) {
            stars <- c('*' = .1, '**' = .05, '***' = .01)
        } else {
            stars_note <- FALSE
        }
    } else {
        stars <- sort(stars, decreasing = TRUE)
    }

    # extract estimates and gof
    dat <- gtsummary::extract(models,
                              statistic = statistic,
                              statistic_override = statistic_override,
                              conf_level = conf_level,
                              coef_map = coef_map,
                              coef_omit = coef_omit,
                              gof_map = gof_map,
                              gof_omit = gof_omit,
                              stars = stars,
                              add_rows = add_rows,
                              fmt = fmt)

    # remove duplicate term labels
    tab <- dat %>%
           dplyr::mutate(term = ifelse(statistic == 'statistic', '', term))

    # create gt table object
    idx <- (1:nrow(tab))[tab$group == 'estimates']
    tab <- tab %>%
           # remove columns not fit for printing
           dplyr::select(-statistic, -group) %>%
           ## group statistics (alternate mechanism. probably better, but I
           ## can't find a way to suppress group labels)
           #dplyr::group_by(group) %>%
           # gt object
           gt::gt(rowname_col = 'term') %>%
           # group statistics
           gt::tab_row_group(group = '', rows = idx)

    # titles
    if (!is.null(title)) {
        tab <- tab %>% gt::tab_header(title = title, subtitle = subtitle)
    }

    # stars note
    if (stars_note & !is.null(stars)) {
        stars_note <- paste0(names(stars), ' p < ', stars)
        stars_note <- paste(stars_note, collapse = ', ')
        tab = tab %>%
              gt::tab_source_note(source_note = stars_note)
    }

    # user-supplied notes at the bottom of table
    if (!is.null(notes)) {
        for (n in notes) {
            tab <- tab %>% gt::tab_source_note(source_note = n)
        }
    }

    # output
    if (!is.null(filename)) {
        gt::gtsave(tab, filename)
    } else {
        return(tab)
    }

}
