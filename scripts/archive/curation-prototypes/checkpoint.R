# Setup & Checkpoint ------------------------------------------------------

# 1. Configuration --------------------------------------------------------
{
  # Define the paths and constraints for this project
  config <- list(
    raw_dir      = here::here("", "raw"),        # Where raw files live
    hash_file    = here::here("", "hashes.csv"), # Where to store hash history
    max_age_days = 90,                               # Rebuild trigger age
    file_pattern = NULL                              # NULL for all, or regex like "\\.csv$"
  )
  
  if (!dir.exists(config$raw_dir)) dir.create(config$raw_dir, recursive = TRUE)
}

## ! Deploy config -------------------------------------------------------------------------

deploy <- FALSE

# 2. Package Management ---------------------------------------------------
{
  # Source the centralized package loader
  # This handles pak installation, OS detection, and library loading
  if (file.exists("load_packages.R")) {
    source("load_packages.R")
  } else {
    stop("load_packages.R not found. Please ensure the package loader is present.")
  }

	if (!requireNamespace("cli", quietly = TRUE)) install.packages("cli")
}

# 3. Helper Functions -----------------------------------------------------

get_file_hashes <- function(dir, pattern = NULL) {
  files <- fs::dir_ls(dir, type = "file", regexp = pattern)
  
  if (length(files) == 0) return(tibble(file = character(), hash = character()))
  
  map(files, function(f) {
    tibble(
      file = fs::path_file(f),
      hash = digest::digest(f, file = TRUE, algo = "md5"),
      mtime = fs::file_info(f)$modification_time
    )
  }) %>% list_rbind()
}

# 4. Checkpoint Logic -----------------------------------------------------

run_rebuild <- FALSE # Default state

cli::cli_h1("Project Checkpoint")

# Get current status of raw files
current_status <- get_file_hashes(config$raw_dir, config$file_pattern)

# CHECK A: Do files exist? (Gross check)
if (nrow(current_status) == 0) {
  # If the directory is totally empty, we must rebuild (unless we expect empty, but usually not)
  # However, if we have a hash file, we might be missing specific files, which is caught in Check C.
  # But if 0 files exist, we can skip straight to rebuild to save time.
  cli::cli_alert_danger("No raw files found in {.path {config$raw_dir}}.")
  run_rebuild <- TRUE
} else {
  # CHECK B: Are existing files too old?
  # (Only checks files that actually exist)
  oldest_file_age <- as.numeric(difftime(Sys.time(), min(current_status$mtime), units = "days"))

  if (oldest_file_age > config$max_age_days) {
    cli::cli_alert_warning(
      "Data files are older than {.val {config$max_age_days}} days ({.val {round(oldest_file_age)}} days)."
    )

    if (interactive()) {
      user_approves <- if (exists("ui_yeah", where = asNamespace("usethis"), mode = "function")) {
        usethis::ui_yeah("Do you want to rebuild the dataset?")
      } else {
        utils::menu(c("Yes", "No"), title = "Do you want to rebuild the dataset?") == 1
      }
      if (user_approves) run_rebuild <- TRUE
    } else {
      run_rebuild <- TRUE
    }
  }

  # CHECK C: Hash Integrity (Missing Files, New Files, Changed Files)
  if (!run_rebuild) {
    if (fs::file_exists(config$hash_file)) {
      saved_hashes <- readr::read_csv(config$hash_file, show_col_types = FALSE)

      # FULL JOIN matches both sides so we see missing AND new files
      integrity_check <- current_status %>%
        select(file, current_hash = hash) %>%
        full_join(saved_hashes %>% select(file, saved_hash = hash), by = "file") %>%
        mutate(
          match = current_hash == saved_hash,
          # Categorize the issue for the user
          status = case_when(
            is.na(current_hash) ~ "MISSING", # In CSV, not in folder
            is.na(saved_hash) ~ "NEW", # In folder, not in CSV
            !match ~ "CHANGED", # In both, hash differs
            TRUE ~ "OK"
          )
        )

      # Filter for problems (Status is not OK)
      problems <- integrity_check %>% filter(status != "OK")

      if (nrow(problems) > 0) {
        cli::cli_alert_warning("Integrity check failed.")

        # Print a nice summary of what is wrong
        print(problems)

        # If files are missing, changed, or new, we trigger a rebuild
        cli::cli_alert_info("Flagging for rebuild due to file mismatch (Missing/New/Changed).")
        run_rebuild <- TRUE
      } else {
        cli::cli_alert_success("File integrity verified (All hashes match).")
      }
    } else {
      cli::cli_alert_info("No hash history found. Generating baseline hashes...")
      current_status %>%
        select(file, hash) %>%
        readr::write_csv(config$hash_file)
    }
  }
}

# 5. Execution / Summary --------------------------------------------------

if (run_rebuild) {
  cli::cli_rule(left = "Action Required: REBUILDING")
  
  # ! ---
  # ! INSERT YOUR DOWNLOAD / RAW PROCESSING CODE HERE
  # ! ---
  
  # Example:
  # download.file(...)
  # unzip(...)
  
  cli::cli_alert_info("Rebuild logic executed (Placeholder).")
  
  # ! ---
  # ! END REBUILD LOGIC
  # ! ---
  
  # Update hashes after rebuild
  cli::cli_alert_info("Updating hash records...")
  new_status <- get_file_hashes(config$raw_dir, config$file_pattern)
  new_status %>% 
    select(file, hash) %>% 
    readr::write_csv(config$hash_file)
  
  cli::cli_alert_success("Rebuild complete and hashes updated.")
  
} else {
  if (deploy) {
  cli::cli_alert_success(
	'Deploying API + Documentation'
	)
  
  rm(deploy)
		
	# ! ---
	# ! LOAD DATA
	# ! ---	
		
	} else {
  cli::cli_alert_success(
	'Deploying local connection'
	)
  rm(deploy)
		
	# ! ---
	# ! LOAD DATA
	# ! --- 	
		
	}
}

# Cleanup
rm(config, current_status, get_file_hashes)