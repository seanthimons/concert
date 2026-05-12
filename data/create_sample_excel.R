# Script to create sample Excel file with frontmatter
sample_path <- here::here("data", "sample_frontmatter.xlsx")

if (!file.exists(sample_path)) {
  # Create a dataframe that includes frontmatter rows
  sample_data <- tibble::tribble(
    ~Col1, ~Col2, ~Col3,
    "Report Title: Employee Data", NA, NA,
    "Generated: 2024-01-15", NA, NA,
    "Department: Human Resources", NA, NA,
    NA, NA, NA,  # Blank row
    "Name", "Age", "Department",
    "Alice Johnson", "25", "Engineering",
    "Bob Smith", "30", "Sales",
    "Charlie Davis", "35", "Marketing",
    "Diana Wilson", "28", "Engineering"
  )

  # Write to Excel
  writexl::write_xlsx(
    list(Sheet1 = sample_data),
    path = sample_path,
    col_names = FALSE
  )

  cat("Sample Excel file with frontmatter created successfully!\n")
}
