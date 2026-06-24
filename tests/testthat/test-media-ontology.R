# test-media-ontology.R
# Source-table validation and runtime ontology metadata for media harmonization.

make_ontology_nodes_fixture <- function() {
  tibble::tibble(
    node_id = c(
      "media",
      "media.liquid",
      "media.liquid.aqueous",
      "media.liquid.aqueous.water",
      "media.liquid.non_aqueous",
      "media.liquid.non_aqueous.vehicle",
      "media.liquid.non_aqueous.vehicle.dmso",
      "media.solid",
      "media.solid.soil"
    ),
    parent_id = c(
      NA_character_,
      "media",
      "media.liquid",
      "media.liquid.aqueous",
      "media.liquid",
      "media.liquid.non_aqueous",
      "media.liquid.non_aqueous.vehicle",
      "media",
      "media.solid"
    ),
    label = c(
      "media",
      "liquid",
      "aqueous",
      "water",
      "non-aqueous",
      "vehicle",
      "dmso",
      "solid",
      "soil"
    ),
    rank = c(
      "root",
      "physical_state",
      "routing",
      "canonical",
      "branch",
      "branch",
      "canonical",
      "routing",
      "canonical"
    ),
    routing_category = c(
      NA_character_,
      NA_character_,
      "aqueous",
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_,
      "solid",
      NA_character_
    ),
    envo_id = c(
      NA_character_,
      NA_character_,
      NA_character_,
      "ENVO:00002006",
      NA_character_,
      NA_character_,
      NA_character_,
      NA_character_,
      "ENVO:00001998"
    ),
    definition = paste("fixture", seq_len(9)),
    active = TRUE
  )
}

make_canonical_media_fixture <- function() {
  tibble::tibble(
    canonical_media = c("aqueous", "water", "soil", "dmso"),
    ontology_node_id = c(
      "media.liquid.aqueous",
      "media.liquid.aqueous.water",
      "media.solid.soil",
      "media.liquid.non_aqueous.vehicle.dmso"
    ),
    routing_category = c("aqueous", "aqueous", "solid", NA_character_),
    envo_id = c(NA_character_, "ENVO:00002006", "ENVO:00001998", NA_character_),
    envo_source = c("concert", "envo", "envo", "concert"),
    active = TRUE
  )
}

make_media_aliases_fixture <- function() {
  tibble::tibble(
    term = c("h2o", "runoff", "dimethyl sulfoxide"),
    canonical_media = c("water", NA_character_, "dmso"),
    assertion_mode = c("auto", "pending", "auto"),
    confidence = c("high", "pending", "medium"),
    source = c("test", "amos", "test"),
    active = TRUE
  )
}

write_media_source_fixture <- function(source_dir,
                                       canonical = make_canonical_media_fixture(),
                                       aliases = make_media_aliases_fixture(),
                                       ontology = make_ontology_nodes_fixture()) {
  readr::write_csv(canonical, file.path(source_dir, "media_canonical.csv"))
  readr::write_csv(aliases, file.path(source_dir, "media_aliases.csv"))
  readr::write_csv(ontology, file.path(source_dir, "media_ontology_nodes.csv"))
}

test_that("media ontology builds stable runtime metadata and derived routes", {
  withr::with_tempdir({
    write_media_source_fixture(getwd())

    source_tables <- concert:::load_media_source_tables(getwd())
    runtime_map <- concert:::build_media_runtime_map(source_tables, fetch_timestamp = "2026-06-24T00:00:00")

    water <- runtime_map[runtime_map$term == "water", ]
    expect_equal(water$media_category, "aqueous")
    expect_equal(water$ontology_node_id, "media.liquid.aqueous.water")
    expect_equal(water$ontology_path, "media > liquid > aqueous > water")
    expect_equal(water$physical_state, "liquid")

    dmso <- runtime_map[runtime_map$term == "dmso", ]
    expect_true(is.na(dmso$media_category))
    expect_equal(dmso$ontology_path, "media > liquid > non-aqueous > vehicle > dmso")
    expect_equal(dmso$physical_state, "liquid")

    runoff <- runtime_map[runtime_map$term == "runoff", ]
    expect_equal(runoff$assertion_mode, "pending")
    expect_true(is.na(runoff$canonical_term))
    expect_true(is.na(runoff$ontology_node_id))
  })
})

test_that("media ontology rejects canonical references to missing node IDs", {
  withr::with_tempdir({
    canonical <- make_canonical_media_fixture()
    canonical$ontology_node_id[canonical$canonical_media == "water"] <- "media.liquid.aqueous.missing"
    write_media_source_fixture(getwd(), canonical = canonical)

    expect_error(
      concert:::load_media_source_tables(getwd()),
      "unknown ontology_node_id"
    )
  })
})

test_that("media ontology rejects parent cycles", {
  withr::with_tempdir({
    ontology <- make_ontology_nodes_fixture()
    ontology$parent_id[ontology$node_id == "media.liquid"] <- "media.liquid.aqueous.water"
    write_media_source_fixture(getwd(), ontology = ontology)

    expect_error(
      concert:::load_media_source_tables(getwd()),
      "parent cycle"
    )
  })
})

test_that("media ontology rejects canonical route mismatches", {
  withr::with_tempdir({
    canonical <- make_canonical_media_fixture()
    canonical$routing_category[canonical$canonical_media == "water"] <- "solid"
    write_media_source_fixture(getwd(), canonical = canonical)

    expect_error(
      concert:::load_media_source_tables(getwd()),
      "does not match ontology-derived route"
    )
  })
})

test_that("canonical media cannot point to non-leaf branch nodes unless explicit routing nodes", {
  withr::with_tempdir({
    canonical <- make_canonical_media_fixture()
    canonical$ontology_node_id[canonical$canonical_media == "dmso"] <- "media.liquid.non_aqueous.vehicle"
    write_media_source_fixture(getwd(), canonical = canonical)

    expect_error(
      concert:::load_media_source_tables(getwd()),
      "cannot reference non-leaf ontology node"
    )
  })
})
