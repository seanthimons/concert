# Packages ----------------------------------------------------------------

{
  # Install pak if it's not already installed
  if (!requireNamespace("pak", quietly = TRUE)) {
    install.packages(
      "pak",
      repos = sprintf(
        "https://r-lib.github.io/p/pak/stable/%s/%s/%s",
        .Platform$pkgType,
        R.Version()$os,
        R.Version()$arch
      )
    )
  }

  linux_binary_repo <- function(universe) {
    sprintf('https://%s.r-universe.dev/bin/linux/noble-%s/%s/', universe, R.version$arch, substr(getRversion(), 1, 3))
  }

  options(repos = linux_binary_repo(c('ropensci', 'cran')))
  rm(linux_binary_repo)

  # CRAN Packages ----
  install_booster_pack <- function(package, load = TRUE) {
    # Loop through each package
    for (pkg in package) {
      # Check if the package is installed
      if (!requireNamespace(pkg, quietly = TRUE)) {
        # If not installed, install the package
        pak::pkg_install(pkg)
      }
      # Load the package
      if (load) {
        library(pkg, character.only = TRUE, quietly = TRUE)
      }
    }
  }

  if (file.exists('packages.txt')) {
    packages <- read.table('packages.txt')

    install_booster_pack(package = packages$Package, load = FALSE)

    rm(packages)
  } else {
    ## Packages ----

		booster_pack <- c(
			### IO ----

			'fs',
			'here',
			'janitor',
			'rio',
			'readxl', # Excel file reading fallback
			'writexl', # Excel file writing for tests
			'tidyverse',
			# 'data.table',
			'mirai',
			'parallel',
			# 'targets',
			# 'crew',
			'digest', # file/ object hashing

			### DB ----

			# 'arrow',
			'nanoparquet',
			# 'duckdb',
			# 'duckplyr',
			# 'dbplyr',

			### EDA ----

			# 'skimr',

			### Web ----

			'rvest',
			'polite',
			# 'plumber',
			# 'plumber2', #Still experimental
			'httr2',
			# 'V8',

			### Plot ----

			# 'paletteer',
			# 'ragg',
			# 'camcorder',
			# 'esquisse',
			# 'geofacet',
			# 'patchwork',
			# 'ggpubr', # Alternative to patchwork
			# 'marquee',
			# 'ggiraph',
			# 'geomtextpath',
			# 'ggpattern',
			# 'ggbump',
			# 'gghighlight',
			# 'ggdist',
			# 'ggforce',
			# 'gghalves',
			# 'ggtext',
			# 'ggrepel', # Suggested for non-overlapping labels
			# 'gganimate', # Suggested for animations
			# 'ggsignif',
			# 'ggTimeSeries',
			# 'tidyheatmaps',
			# 'ggdendro',
			# 'ggstatsplot',

			### Modeling ----

			# 'tidymodels',
			# 'MuMIn',

			### Shiny ----

			'shiny',
			'bslib',
			'bsicons', # Icons for Shiny UI
			'DT',
			'shinyjs', # JavaScript helpers for Shiny
			# 'plotly',

			### Reporting ----

			# 'quarto',
			# 'gt',
			# 'gtsummary',

			### Spatial ----

			# 'sf',
			# 'geoarrow',
			# 'duckdbfs',
			# 'duckspatial',
			# 'ducksf',
			# 'tidycensus', # Needs API
			# 'mapgl',
			# 'dataRetrieval', # Needs API
			# 'StreamCatTools',

			### Testing ----

			'testthat', # Unit testing framework

			### Misc ----

			'devtools',
			# 'usethis',
			'remotes'
		)

		# ! Change load flag to load packages
    install_booster_pack(package = booster_pack, load = TRUE)
    rm(install_booster_pack, booster_pack)
  }

  # GitHub Packages ----
  # github_packages <- c(
  # 	"seanthimons/ComptoxR"
  # )

  # # Ensure remotes is installed
  # if (!requireNamespace("remotes", quietly = TRUE)) {
  # 	install.packages("remotes")
  # }

  # # Loop through each GitHub package
  # for (pkg in github_packages) {
  # 	# Extract package name from the "user/repo" string
  # 	pkg_name <- sub(".*/", "", pkg)

  # 	# Check if the package is installed
  # 	if (!requireNamespace(pkg_name, quietly = TRUE)) {
  # 		# If not installed, install the latest release from GitHub
  # 		remotes::install_github(paste0(pkg, "@*release"))
  # 	}
  # 	# Load the package
  # 	library(pkg_name, character.only = TRUE)
  # }

  # rm(github_packages, pkg, pkg_name)

	# Custom Functions ----

	`%ni%` <- Negate(`%in%`)

	# geometric_mean <- function(x) {
	#   exp(mean(log(x[x > 0])))
	# }

	# my_skim <- skim_with(
	#   numeric = sfl(
	#     n = length,
	#     min = ~ min(.x, na.rm = TRUE),
	#     p25 = ~ stats::quantile(., probs = .25, na.rm = TRUE, names = FALSE),
	#     med = ~ median(.x, na.rm = TRUE),
	#     p75 = ~ stats::quantile(., probs = .75, na.rm = TRUE, names = FALSE),
	#     max = ~ max(.x, na.rm = TRUE),
	#     mean = ~ mean(.x, na.rm = TRUE),
	#     geo_mean = ~ geometric_mean(.x),
	#     sd = ~ stats::sd(., na.rm = TRUE),
	#     hist = ~ inline_hist(., 5)
	#   ),
	#   append = FALSE
	# )

	# Mirai ----

	# daemons(n = parallel::detectCores() - 2)

	# Camcorder ----

	# if(!dir.exists(here::here('output'))) {
	#   dir.create(here::here('output'))
	# }

	# gg_record(
	# 	here::here('output'),
	# 	device = "png",
	# 	width = 10,
	# 	height = 7,
	# 	units = "in",
	# 	dpi = 320
	# )

	# Theme ----

	# theme_custom <- function() {
	# 	theme_minimal() +
	# 		theme(
	# 			plot.background = element_rect(colour = "white"),
	# 			panel.grid.major = element_blank(),
	# 			panel.grid.minor = element_blank(),
	# 			strip.background = element_rect(colour = "white"),
	# 			axis.text.x = element_text(angle = 90L)
	# 		)
	# }
	
	# Air TOML file setup -------------------------------------------------------------------

  if (!file.exists("air.toml")) {
    writeLines(
		"[format]
		line-width = 120
		indent-width = 2
		indent-style = \"space\"
		line-ending = \"auto\"
		persistent-line-breaks = true
		exclude = []
		default-exclude = true
		skip = []
		table = []
		default-table = true",
      "air.toml"
    )
  }
}