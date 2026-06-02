#!/usr/bin/env Rscript
# ==============================================================================
# Synthetic Watershed Monitoring Dataset Generator — MULTI-MEDIA
# ==============================================================================
# Extends the original water-only generator to include co-located sampling in:
#   - surface_water  (ug/L, ng/L, mg/L, etc.)
#   - sediment       (mg/kg dry weight; ng/g for PFAS)
#   - soil           (mg/kg dry weight; ng/g for PFAS)
#   - fish_tissue    (ug/kg or ng/g wet weight; whole-body or fillet)
#   - groundwater    (ug/L, ng/L; co-located monitoring wells)
#   - air            (ng/m^3 via passive samplers; gas-phase only)
#
# Outputs:
#   1. sites.csv             - Site metadata
#   2. chemicals.csv         - Chemical portfolio (water-phase reference)
#   3. media_applicability.csv - Which analytes are reported in which media
#   4. sampling_events.csv   - Long table: site x event x medium x method
#   5. method_coverage.csv   - Site x year x domain x medium availability
#   6. detections.csv        - Long tidy detections (with `medium` column)
#   7. detections_quick_test_20_per_compound.csv - Random 20 records per analyte
#   8. bioassay.csv          - AhR bioassay (water + sediment porewater)
#
# Design decisions:
#   - Co-location: water/sediment/fish share site_id; wells & passive samplers
#     are co-located but get a sub-id (e.g., SITE-03-MW, SITE-03-AIR).
#   - Media-appropriate units & detection limits (sediment/soil in mg/kg or
#     ng/g; tissue in ng/g ww; air in ng/m^3).
#   - Partitioning: a chemical's media-specific concentration is generated from
#     the water-phase concentration via a log-Koc / log-BCF-style scalar per
#     domain. Noise added so it's not deterministic.
#   - Fish tissue only carries bioaccumulative analytes (PFAS, Hg, lipophilic
#     SVOCs, some hydrocarbons). VOCs and most WQ parameters not reported.
#   - Soil only at near-discharge & far-field reference locations.
#   - Sediment co-located with surface water at all sites.
#   - Groundwater (monitoring wells) only at discharge_point + near_field.
#   - Air (passive samplers) only at a subset; only volatile/semi-volatile.
#   - Sampling frequency varies by medium: water monthly, sediment annual,
#     fish annual, groundwater quarterly, soil biennial, air quarterly.
#   - Sparsity is STRUCTURAL (method/medium availability) and STOCHASTIC
#     (detection probability).
# ==============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)
library(tibble)

set.seed(42)

# --- Configuration -----------------------------------------------------------

n_sites       <- 18
n_years       <- 12        # 2013-2024
years         <- 2013:2024
quick_test_n_per_compound <- 20

# --- Chemical hierarchy -------------------------------------------------------

make_chem <- function(order, family, domain, analyte, cas, units, conc, det_class,
                      half_life_days = NA_real_,
                      radionuclide_interest_window = NA_character_) {
  tibble(order=order, family=family, domain=domain, analyte=analyte,
         cas=cas, units=units, typical_conc_ug_l=conc,
         detection_class=det_class,
         half_life_days=half_life_days,
         radionuclide_interest_window=radionuclide_interest_window)
}

make_rad <- function(family, analyte, id, units, conc, det_class,
                     half_life_days = NA_real_,
                     interest_window = "long_term") {
  make_chem("Radionuclides", family, "Radionuclides", analyte, id, units,
            conc, det_class,
            half_life_days = half_life_days,
            radionuclide_interest_window = interest_window)
}

chemical_portfolio <- bind_rows(
  # --- VOCs ---
  make_chem("Organics","Volatiles","VOCs","Benzene","71-43-2","ug/L",2.5,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","Toluene","108-88-3","ug/L",5.0,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","Ethylbenzene","100-41-4","ug/L",1.2,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","Xylenes (total)","1330-20-7","ug/L",3.8,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","Chloroform","67-66-3","ug/L",4.1,"ubiquitous"),
  make_chem("Organics","Volatiles","VOCs","1,1-Dichloroethene","75-35-4","ug/L",0.8,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","Trichloroethylene","79-01-6","ug/L",1.5,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","Tetrachloroethylene","127-18-4","ug/L",0.9,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","Methyl tert-butyl ether","1634-04-4","ug/L",3.2,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","Vinyl chloride","75-01-4","ug/L",0.3,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","1,2-Dichloroethane","107-06-2","ug/L",0.6,"discharge_driven"),
  make_chem("Organics","Volatiles","VOCs","Carbon tetrachloride","56-23-5","ug/L",0.4,"rare_hit"),
  # --- SVOCs ---
  make_chem("Organics","Semivolatiles","SVOCs","Benzo(a)pyrene","50-32-8","ug/L",0.02,"discharge_driven"),
  make_chem("Organics","Semivolatiles","SVOCs","Naphthalene","91-20-3","ug/L",1.8,"discharge_driven"),
  make_chem("Organics","Semivolatiles","SVOCs","Fluoranthene","206-44-0","ug/L",0.15,"discharge_driven"),
  make_chem("Organics","Semivolatiles","SVOCs","Pyrene","129-00-0","ug/L",0.12,"discharge_driven"),
  make_chem("Organics","Semivolatiles","SVOCs","Phenanthrene","85-01-8","ug/L",0.25,"discharge_driven"),
  make_chem("Organics","Semivolatiles","SVOCs","Bis(2-ethylhexyl) phthalate","117-81-7","ug/L",1.5,"ubiquitous"),
  make_chem("Organics","Semivolatiles","SVOCs","Di-n-butyl phthalate","84-74-2","ug/L",0.8,"ubiquitous"),
  make_chem("Organics","Semivolatiles","SVOCs","Pentachlorophenol","87-86-5","ug/L",0.5,"discharge_driven"),
  make_chem("Organics","Semivolatiles","SVOCs","2,4-Dinitrotoluene","121-14-2","ug/L",0.3,"rare_hit"),
  # --- Hydrocarbons ---
  make_chem("Organics","Hydrocarbons","Hydrocarbons","TPH-DRO (C10-C28)","NA-DRO","ug/L",120,"discharge_driven"),
  make_chem("Organics","Hydrocarbons","Hydrocarbons","TPH-GRO (C6-C10)","NA-GRO","ug/L",85,"discharge_driven"),
  make_chem("Organics","Hydrocarbons","Hydrocarbons","TPH-ORO (C28-C36)","NA-ORO","ug/L",45,"discharge_driven"),
  make_chem("Organics","Hydrocarbons","Hydrocarbons","Oil & Grease","NA-OG","mg/L",5.0,"discharge_driven"),
  # --- PFAS ---
  make_chem("Organics","PFAS","PFAS","PFOS","1763-23-1","ng/L",18,"discharge_driven"),
  make_chem("Organics","PFAS","PFAS","PFOA","335-67-1","ng/L",12,"discharge_driven"),
  make_chem("Organics","PFAS","PFAS","PFHxS","355-46-4","ng/L",8.5,"discharge_driven"),
  make_chem("Organics","PFAS","PFAS","PFNA","375-95-1","ng/L",3.2,"discharge_driven"),
  make_chem("Organics","PFAS","PFAS","PFDA","335-76-2","ng/L",2.1,"discharge_driven"),
  make_chem("Organics","PFAS","PFAS","PFUnDA","2058-94-8","ng/L",1.5,"rare_hit"),
  make_chem("Organics","PFAS","PFAS","PFBS","375-73-5","ng/L",6.0,"discharge_driven"),
  make_chem("Organics","PFAS","PFAS","PFHxA","307-24-4","ng/L",9.0,"ubiquitous"),
  make_chem("Organics","PFAS","PFAS","PFHpA","375-85-9","ng/L",4.0,"discharge_driven"),
  make_chem("Organics","PFAS","PFAS","PFBA","375-22-4","ng/L",15,"ubiquitous"),
  make_chem("Organics","PFAS","PFAS","6:2 FTS","27619-97-2","ng/L",5.5,"discharge_driven"),
  make_chem("Organics","PFAS","PFAS","8:2 FTS","39108-34-4","ng/L",2.8,"rare_hit"),
  make_chem("Organics","PFAS","PFAS","ADONA","919005-14-4","ng/L",1.0,"rare_hit"),
  make_chem("Organics","PFAS","PFAS","GenX (HFPO-DA)","13252-13-6","ng/L",7.0,"discharge_driven"),
  make_chem("Organics","PFAS","PFAS","PFMBA","863090-89-5","ng/L",0.8,"rare_hit"),
  make_chem("Organics","PFAS","PFAS","PFMPA","377-73-1","ng/L",0.5,"rare_hit"),
  make_chem("Organics","PFAS","PFAS","NEtFOSAA","2991-50-6","ng/L",1.2,"rare_hit"),
  make_chem("Organics","PFAS","PFAS","NMeFOSAA","2355-31-9","ng/L",1.0,"rare_hit"),
  # --- Metals ---
  make_chem("Inorganics","Metals","Metals","Arsenic","7440-38-2","ug/L",5.0,"ubiquitous"),
  make_chem("Inorganics","Metals","Metals","Cadmium","7440-43-9","ug/L",0.5,"ubiquitous"),
  make_chem("Inorganics","Metals","Metals","Chromium","7440-47-3","ug/L",3.0,"ubiquitous"),
  make_chem("Inorganics","Metals","Metals","Copper","7440-50-8","ug/L",8.0,"ubiquitous"),
  make_chem("Inorganics","Metals","Metals","Lead","7439-92-1","ug/L",2.5,"ubiquitous"),
  make_chem("Inorganics","Metals","Metals","Mercury","7439-97-6","ug/L",0.1,"discharge_driven"),
  make_chem("Inorganics","Metals","Metals","Nickel","7440-02-0","ug/L",6.0,"ubiquitous"),
  make_chem("Inorganics","Metals","Metals","Selenium","7782-49-2","ug/L",2.0,"ubiquitous"),
  make_chem("Inorganics","Metals","Metals","Zinc","7440-66-6","ug/L",25.0,"ubiquitous"),
  make_chem("Inorganics","Metals","Metals","Thallium","7440-28-0","ug/L",0.3,"rare_hit"),
  make_chem("Inorganics","Metals","Metals","Antimony","7440-36-0","ug/L",1.5,"discharge_driven"),
  make_chem("Inorganics","Metals","Metals","Barium","7440-39-3","ug/L",50.0,"ubiquitous"),
  make_chem("Inorganics","Metals","Metals","Beryllium","7440-41-7","ug/L",0.2,"rare_hit"),
  make_chem("Inorganics","Metals","Metals","Silver","7440-22-4","ug/L",0.3,"rare_hit"),
  make_chem("Inorganics","Metals","Metals","Vanadium","7440-62-2","ug/L",4.0,"ubiquitous"),
  # --- Radionuclides ---
  make_rad("Screening Radionuclides","Gross Alpha","NA-GALPHA","pCi/L",8.0,"ubiquitous",
           interest_window = "screening"),
  make_rad("Screening Radionuclides","Gross Beta","NA-GBETA","pCi/L",12.0,"ubiquitous",
           interest_window = "screening"),
  make_rad("Naturally Occurring Radionuclides","Radium-226","13982-63-3","pCi/L",2.0,"ubiquitous",
           1600 * 365.25, "long_term"),
  make_rad("Naturally Occurring Radionuclides","Radium-228","15262-20-1","pCi/L",1.5,"ubiquitous",
           5.75 * 365.25, "long_term"),
  make_rad("Naturally Occurring Radionuclides","Radon-222","NA-RN222","pCi/L",300,"ubiquitous",
           3.82, "short_term"),
  make_rad("Naturally Occurring Radionuclides","Uranium","7440-61-1","ug/L",3.0,"ubiquitous",
           interest_window = "long_term"),
  make_rad("Naturally Occurring Radionuclides","Uranium-234","NA-U234","pCi/L",0.6,"ubiquitous",
           2.455e5 * 365.25, "long_term"),
  make_rad("Naturally Occurring Radionuclides","Uranium-235","NA-U235","pCi/L",0.05,"ubiquitous",
           7.04e8 * 365.25, "long_term"),
  make_rad("Naturally Occurring Radionuclides","Uranium-238","NA-U238","pCi/L",0.4,"ubiquitous",
           4.468e9 * 365.25, "long_term"),
  make_rad("Naturally Occurring Radionuclides","Thorium-230","NA-TH230","pCi/L",0.03,"rare_hit",
           7.538e4 * 365.25, "long_term"),
  make_rad("Naturally Occurring Radionuclides","Thorium-232","NA-TH232","pCi/L",0.02,"rare_hit",
           1.405e10 * 365.25, "long_term"),
  make_rad("Short-Term Radionuclides","Iodine-131","NA-I131","pCi/L",0.2,"rare_hit",
           8.02, "short_term"),
  make_rad("Short-Term Radionuclides","Barium-140","NA-BA140","pCi/L",0.08,"rare_hit",
           12.75, "short_term"),
  make_rad("Short-Term Radionuclides","Lanthanum-140","NA-LA140","pCi/L",0.05,"rare_hit",
           1.68, "short_term"),
  make_rad("Short-Term Radionuclides","Ruthenium-103","NA-RU103","pCi/L",0.07,"rare_hit",
           39.26, "short_term"),
  make_rad("Short-Term Radionuclides","Zirconium-95","NA-ZR95","pCi/L",0.06,"rare_hit",
           64.0, "short_term"),
  make_rad("Short-Term Radionuclides","Cerium-141","NA-CE141","pCi/L",0.06,"rare_hit",
           32.5, "short_term"),
  make_rad("Short-Term Radionuclides","Cesium-134","NA-CS134","pCi/L",0.15,"rare_hit",
           2.06 * 365.25, "short_term"),
  make_rad("Short-Term Radionuclides","Cobalt-58","NA-CO58","pCi/L",0.04,"rare_hit",
           70.86, "short_term"),
  make_rad("Short-Term Radionuclides","Manganese-54","NA-MN54","pCi/L",0.04,"rare_hit",
           312.2, "short_term"),
  make_rad("Short-Term Radionuclides","Tritium","10028-17-8","pCi/L",500,"discharge_driven",
           12.32 * 365.25, "short_term"),
  make_rad("Long-Term Radionuclides","Strontium-90","10098-97-2","pCi/L",0.5,"rare_hit",
           28.79 * 365.25, "long_term"),
  make_rad("Long-Term Radionuclides","Cesium-137","NA-CS137","pCi/L",0.4,"rare_hit",
           30.17 * 365.25, "long_term"),
  make_rad("Long-Term Radionuclides","Cobalt-60","NA-CO60","pCi/L",0.1,"rare_hit",
           5.27 * 365.25, "long_term"),
  make_rad("Long-Term Radionuclides","Technetium-99","NA-TC99","pCi/L",1.0,"discharge_driven",
           2.11e5 * 365.25, "long_term"),
  make_rad("Long-Term Radionuclides","Iodine-129","NA-I129","pCi/L",0.02,"rare_hit",
           1.57e7 * 365.25, "long_term"),
  make_rad("Long-Term Radionuclides","Carbon-14","NA-C14","pCi/L",50,"ubiquitous",
           5730 * 365.25, "long_term"),
  make_rad("Long-Term Radionuclides","Nickel-63","NA-NI63","pCi/L",0.08,"rare_hit",
           100.1 * 365.25, "long_term"),
  make_rad("Transuranic Radionuclides","Neptunium-237","NA-NP237","pCi/L",0.005,"rare_hit",
           2.144e6 * 365.25, "long_term"),
  make_rad("Transuranic Radionuclides","Plutonium-238","NA-PU238","pCi/L",0.01,"rare_hit",
           87.7 * 365.25, "long_term"),
  make_rad("Transuranic Radionuclides","Plutonium-239","NA-PU239","pCi/L",0.01,"rare_hit",
           24110 * 365.25, "long_term"),
  make_rad("Transuranic Radionuclides","Plutonium-240","NA-PU240","pCi/L",0.008,"rare_hit",
           6561 * 365.25, "long_term"),
  make_rad("Transuranic Radionuclides","Americium-241","NA-AM241","pCi/L",0.01,"rare_hit",
           432.2 * 365.25, "long_term"),
  # --- WQ Parameters ---
  make_chem("WQ_Parameters","Conventional","WQ_Metrics","pH","NA-PH","SU",7.2,"ubiquitous"),
  make_chem("WQ_Parameters","Conventional","WQ_Metrics","Dissolved Oxygen","NA-DO","mg/L",7.5,"ubiquitous"),
  make_chem("WQ_Parameters","Conventional","WQ_Metrics","Specific Conductance","NA-SPCOND","uS/cm",450,"ubiquitous"),
  make_chem("WQ_Parameters","Conventional","WQ_Metrics","Turbidity","NA-TURB","NTU",15.0,"ubiquitous"),
  make_chem("WQ_Parameters","Conventional","WQ_Metrics","Temperature","NA-TEMP","degC",18.0,"ubiquitous"),
  make_chem("WQ_Parameters","Conventional","WQ_Metrics","Total Dissolved Solids","NA-TDS","mg/L",300,"ubiquitous"),
  make_chem("WQ_Parameters","Nutrients","WQ_Metrics","Nitrate as N","14797-55-8","mg/L",2.5,"ubiquitous"),
  make_chem("WQ_Parameters","Nutrients","WQ_Metrics","Total Phosphorus","NA-TP","mg/L",0.15,"ubiquitous"),
  make_chem("WQ_Parameters","Nutrients","WQ_Metrics","Ammonia as N","7664-41-7","mg/L",0.5,"discharge_driven")
) %>%
  mutate(analyte_id = row_number())

cat("Chemical portfolio:", nrow(chemical_portfolio), "analytes across",
    n_distinct(chemical_portfolio$domain), "domains\n")

# --- Sites along the watershed ------------------------------------------------

sites <- tibble(
  site_id = paste0("SITE-", str_pad(1:n_sites, 2, pad = "0")),
  river_km = sort(c(0.5, 1.0, 2.0, 2.5, 3.0, 4.0, 5.0, 5.5, 6.5, 8.0,
                    10.0, 12.0, 15.0, 18.0, 22.0, 25.0, 28.0, 32.0)),
  dist_discharge_1_km = abs(river_km - 2.0),
  dist_discharge_2_km = abs(river_km - 5.0),
  dist_nearest_discharge_km = pmin(dist_discharge_1_km, dist_discharge_2_km),
  lat = 39.1 + river_km * 0.002 + rnorm(n_sites, 0, 0.001),
  lon = -84.5 - river_km * 0.003 + rnorm(n_sites, 0, 0.001),
  site_type = case_when(
    river_km %in% c(2.0, 5.0)        ~ "discharge_point",
    dist_nearest_discharge_km <= 1.5 ~ "near_field",
    dist_nearest_discharge_km <= 5.0 ~ "mid_field",
    TRUE                             ~ "far_field"
  )
)

cat("Sites generated:", nrow(sites), "\n")

# --- Media definitions --------------------------------------------------------
# Each medium has: a code, units convention, sampling frequency, and the set
# of site_types where it's collected.

media <- tribble(
  ~medium,           ~matrix_class, ~freq_per_year, ~site_type_filter,
  "surface_water",   "aqueous",     12,             c("discharge_point","near_field","mid_field","far_field"),
  "groundwater",     "aqueous",     4,              c("discharge_point","near_field"),
  "sediment",        "solid",       1,              c("discharge_point","near_field","mid_field","far_field"),
  "soil",            "solid",       0.5,            c("discharge_point","near_field","far_field"),
  "fish_tissue",     "biota",       1,              c("near_field","mid_field","far_field"),
  "air",             "gas",         4,              c("discharge_point","near_field","far_field")
)

# --- Media applicability: which domains show up in which media ---------------
# Not every analyte is reported in every medium. This is the structural
# medium-by-domain matrix.

media_applicability <- expand_grid(
  medium = media$medium,
  domain = unique(chemical_portfolio$domain)
) %>%
  mutate(
    applicable = case_when(
      # Surface water & groundwater: everything except (groundwater rarely runs WQ_Metrics field-style)
      medium %in% c("surface_water") ~ TRUE,
      medium == "groundwater" & domain == "WQ_Metrics" ~ FALSE,
      medium == "groundwater" ~ TRUE,
      # Sediment: organics + metals + radionuclides (no WQ metrics, no volatile gases reliably)
      medium == "sediment" & domain %in% c("SVOCs","Hydrocarbons","PFAS","Metals","Radionuclides") ~ TRUE,
      medium == "sediment" & domain == "VOCs" ~ TRUE,   # less reliable but reported
      medium == "sediment" ~ FALSE,
      # Soil: same as sediment
      medium == "soil" & domain %in% c("SVOCs","Hydrocarbons","PFAS","Metals","Radionuclides") ~ TRUE,
      medium == "soil" & domain == "VOCs" ~ TRUE,
      medium == "soil" ~ FALSE,
      # Fish tissue: only bioaccumulative — PFAS, Hg & lipophilic SVOCs/hydrocarbons
      medium == "fish_tissue" & domain %in% c("PFAS","SVOCs","Hydrocarbons") ~ TRUE,
      medium == "fish_tissue" & domain == "Metals" ~ TRUE,  # filtered to Hg/Se/As at analyte level
      medium == "fish_tissue" ~ FALSE,
      # Air: VOCs, SVOCs (gas-phase PAHs), PFAS (limited; emerging)
      medium == "air" & domain %in% c("VOCs","SVOCs") ~ TRUE,
      medium == "air" & domain == "PFAS" ~ TRUE,
      medium == "air" ~ FALSE,
      TRUE ~ FALSE
    )
  )

# Analyte-level fish tissue filter: only bioaccumulative metals
fish_tissue_metals <- c("Mercury","Selenium","Arsenic","Lead","Cadmium")
# Analyte-level fish tissue filter for SVOCs (lipophilic PAHs and phthalates)
fish_tissue_svocs <- c("Benzo(a)pyrene","Fluoranthene","Pyrene","Phenanthrene",
                       "Bis(2-ethylhexyl) phthalate")
# Air-phase PFAS (volatile precursors only)
air_pfas <- c("6:2 FTS","8:2 FTS","NEtFOSAA","NMeFOSAA")

# --- Media-specific units & partitioning factors ------------------------------
# How a chemical's concentration in surface water translates to other media.
# These are scalar multipliers applied to the water-phase concentration after
# log-transformation. They're NOT real Koc/BCF values — they're synthetic
# stand-ins that reproduce the right rank-order behavior.

partitioning <- tribble(
  ~domain,         ~medium,         ~units,    ~log_partition_mu, ~log_partition_sd,
  # Sediment: organics partition strongly to OC; metals bind to Fe/Mn oxides
  "VOCs",          "sediment",      "ug/kg",    0.5,  0.4,
  "SVOCs",         "sediment",      "ug/kg",    3.5,  0.5,   # high Koc
  "Hydrocarbons",  "sediment",      "mg/kg",    2.8,  0.5,
  "PFAS",          "sediment",      "ng/g",     1.2,  0.6,
  "Metals",        "sediment",      "mg/kg",    3.0,  0.4,   # ug/L -> mg/kg (factor of 1000 + binding)
  "Radionuclides", "sediment",      "pCi/g",    1.5,  0.4,
  # Soil: similar to sediment but typically lower water phase, drier
  "VOCs",          "soil",          "ug/kg",    0.3,  0.5,
  "SVOCs",         "soil",          "ug/kg",    3.3,  0.5,
  "Hydrocarbons",  "soil",          "mg/kg",    2.6,  0.5,
  "PFAS",          "soil",          "ng/g",     1.0,  0.6,
  "Metals",        "soil",          "mg/kg",    2.8,  0.4,
  "Radionuclides", "soil",          "pCi/g",    1.4,  0.4,
  # Fish tissue: bioaccumulation
  "PFAS",          "fish_tissue",   "ng/g",     1.8,  0.5,   # PFOS BCF ~1000-3000
  "SVOCs",         "fish_tissue",   "ug/kg",    2.5,  0.6,   # lipophilic PAH/phthalate
  "Hydrocarbons",  "fish_tissue",   "mg/kg",    1.5,  0.5,
  "Metals",        "fish_tissue",   "mg/kg",    1.0,  0.5,   # Hg biomagnifies
  # Air: passive sampler ng/m^3; volatiles partition strongly, SVOCs less so
  "VOCs",          "air",           "ng/m3",    1.5,  0.5,   # Henry's law-driven
  "SVOCs",         "air",           "ng/m3",    -0.5, 0.6,
  "PFAS",          "air",           "pg/m3",    -0.2, 0.7,
  # Groundwater: same units as surface water but different concentrations
  "VOCs",          "groundwater",   "ug/L",     0.3,  0.5,   # often higher in groundwater (plume)
  "SVOCs",         "groundwater",   "ug/L",     -0.3, 0.5,
  "Hydrocarbons",  "groundwater",   "ug/L",     0.0,  0.5,
  "PFAS",          "groundwater",   "ng/L",     0.5,  0.5,   # PFAS migrate well in groundwater
  "Metals",        "groundwater",   "ug/L",     0.0,  0.4,
  "Radionuclides", "groundwater",   "pCi/L",    0.2,  0.4,
  # Surface water: identity (everything stays in original units)
  "VOCs",          "surface_water", "ug/L",     0.0,  0.0,
  "SVOCs",         "surface_water", "ug/L",     0.0,  0.0,
  "Hydrocarbons",  "surface_water", "ug/L",     0.0,  0.0,
  "PFAS",          "surface_water", "ng/L",     0.0,  0.0,
  "Metals",        "surface_water", "ug/L",     0.0,  0.0,
  "Radionuclides", "surface_water", "pCi/L",    0.0,  0.0,
  "WQ_Metrics",    "surface_water", "mixed",    0.0,  0.0
)

# Hydrocarbons unit override for surface water Oil & Grease (mg/L) preserved
# via per-analyte units already in chemical_portfolio.

# --- Sample-collection identifiers --------------------------------------------
# A sample gets a sub-id appended to the site_id to make co-location explicit:
#   SITE-03            (surface water)
#   SITE-03-MW         (monitoring well, groundwater)
#   SITE-03-SED        (sediment)
#   SITE-03-SOIL       (soil)
#   SITE-03-FISH       (fish tissue)
#   SITE-03-AIR        (passive air sampler)

medium_suffix <- c(
  surface_water = "",
  groundwater   = "-MW",
  sediment      = "-SED",
  soil          = "-SOIL",
  fish_tissue   = "-FISH",
  air           = "-AIR"
)

# --- Method & medium coverage by site ----------------------------------------
# Two-step: (1) is medium collected at this site at all? (2) within medium,
# which analytical domains were run in which years?

# Step 1: site x medium availability
site_medium <- map_dfr(seq_len(nrow(media)), function(i) {
  m  <- media$medium[i]
  st <- media$site_type_filter[[i]]
  sites %>%
    filter(site_type %in% st) %>%
    transmute(site_id, site_type, medium = m,
              sample_id = paste0(site_id, medium_suffix[m]))
})

cat("\nSite x medium combinations:\n")
site_medium %>% count(medium) %>% print()

# Step 2: medium x year x domain coverage
# Re-use original coverage_probs but condition on media_applicability
method_domains <- tibble(
  domain = c("VOCs", "SVOCs", "Hydrocarbons", "PFAS", "Metals",
             "Radionuclides", "WQ_Metrics"),
  method_name_water = c("SW-846 8260", "SW-846 8270", "SW-846 8015/418.1",
                        "EPA 533/537.1", "SW-846 6020", "EPA 900.0/903.0",
                        "Field/SM Methods"),
  method_name_solid = c("SW-846 8260D", "SW-846 8270E", "SW-846 8015D",
                        "EPA 1633", "SW-846 6020B/SW-846 7471 (Hg)",
                        "EPA 901.1/903.1", NA_character_),
  method_name_tissue = c(NA_character_, "SW-846 8270 (modified)",
                         "SW-846 8015 (modified)", "EPA 1633",
                         "EPA 200.8 / 7473 (Hg)", NA_character_, NA_character_),
  method_name_air = c("TO-15", "TO-13A", NA_character_, "Modified TO-13A",
                      NA_character_, NA_character_, NA_character_)
)

# Coverage probabilities (water-side baseline; modified per medium)
coverage_probs_water <- expand_grid(
  site_type = c("discharge_point", "near_field", "mid_field", "far_field"),
  domain = method_domains$domain
) %>%
  mutate(
    prob = case_when(
      domain == "WQ_Metrics" ~ 0.98,
      domain == "Metals"     ~ 0.95,
      domain == "Radionuclides" ~ 0.80,
      domain == "PFAS" & site_type == "discharge_point" ~ 0.95,
      domain == "PFAS" & site_type == "near_field"      ~ 0.85,
      domain == "PFAS" & site_type == "mid_field"        ~ 0.50,
      domain == "PFAS" & site_type == "far_field"        ~ 0.25,
      domain %in% c("VOCs","SVOCs") & site_type == "discharge_point" ~ 0.95,
      domain %in% c("VOCs","SVOCs") & site_type == "near_field"      ~ 0.85,
      domain %in% c("VOCs","SVOCs") & site_type == "mid_field"        ~ 0.60,
      domain %in% c("VOCs","SVOCs") & site_type == "far_field"        ~ 0.30,
      domain == "Hydrocarbons" & site_type == "discharge_point" ~ 0.90,
      domain == "Hydrocarbons" & site_type == "near_field"      ~ 0.75,
      domain == "Hydrocarbons" & site_type == "mid_field"        ~ 0.40,
      domain == "Hydrocarbons" & site_type == "far_field"        ~ 0.15,
      TRUE ~ 0.50
    )
  )

# Medium-specific multipliers on coverage prob (programs are leaner for solids/biota)
medium_cov_multiplier <- tribble(
  ~medium,         ~mult,
  "surface_water", 1.00,
  "groundwater",   0.85,
  "sediment",      0.70,
  "soil",          0.55,
  "fish_tissue",   0.65,
  "air",           0.45
)

method_coverage <- expand_grid(
  site_id = sites$site_id,
  year = years,
  domain = method_domains$domain,
  medium = media$medium
) %>%
  inner_join(site_medium %>% select(site_id, medium, sample_id),
             by = c("site_id","medium")) %>%
  left_join(sites %>% select(site_id, site_type), by = "site_id") %>%
  left_join(media_applicability, by = c("medium","domain")) %>%
  filter(applicable) %>%
  left_join(coverage_probs_water, by = c("site_type","domain")) %>%
  left_join(medium_cov_multiplier, by = "medium") %>%
  mutate(
    prob = prob * mult,
    # PFAS methods weren't widely deployed until ~2018
    prob = if_else(domain == "PFAS" & year < 2018, prob * 0.1, prob),
    # EPA 1633 (PFAS in solids/tissue) really only validated 2022+
    prob = if_else(domain == "PFAS" & medium %in% c("sediment","soil","fish_tissue") & year < 2022,
                   prob * 0.1, prob),
    # Hydrocarbons added at more sites over time
    prob = if_else(domain == "Hydrocarbons" & year < 2016, prob * 0.5, prob),
    # Air monitoring didn't really ramp until ~2017
    prob = if_else(medium == "air" & year < 2017, prob * 0.2, prob),
    method_available = rbinom(n(), 1, pmin(prob, 0.99))
  ) %>%
  select(site_id, sample_id, medium, year, domain, site_type, method_available)

cat("\nMethod coverage summary (fraction of site-year-medium combos with method):\n")
method_coverage %>%
  group_by(medium, domain) %>%
  summarise(pct_available = round(mean(method_available), 2), .groups = "drop") %>%
  pivot_wider(names_from = domain, values_from = pct_available) %>%
  print()

# --- Sampling event calendar per medium ---------------------------------------
# Different media have different sampling frequencies.
build_events <- function(medium_name, freq_per_year) {
  if (freq_per_year == 12) {
    months <- 1:12
  } else if (freq_per_year == 4) {
    months <- c(2, 5, 8, 11)        # quarterly
  } else if (freq_per_year == 1) {
    months <- 9                     # annual fall sampling (low flow / lipid stable)
  } else if (freq_per_year == 0.5) {
    # biennial: every other year
    return(
      tibble(year = years[seq(1, length(years), by = 2)], month = 9) %>%
        mutate(medium = medium_name,
               sample_date = as.Date(paste(year, month, 15, sep = "-")))
    )
  }
  expand_grid(year = years, month = months) %>%
    mutate(medium = medium_name,
           sample_date = as.Date(paste(year, month, 15, sep = "-")))
}

sampling_calendar <- pmap_dfr(
  list(media$medium, media$freq_per_year),
  build_events
) %>%
  arrange(medium, sample_date) %>%
  mutate(event_id = row_number())

# Cross with sites (only where medium applies)
sampling_events <- site_medium %>%
  inner_join(sampling_calendar, by = "medium",
             relationship = "many-to-many") %>%
  mutate(event_sample_id = paste(sample_id, format(sample_date, "%Y%m"), sep = "_")) %>%
  select(event_sample_id, sample_id, site_id, site_type, medium,
         sample_date, year = year, month = month, event_id)

cat("\nSampling events per medium:\n")
sampling_events %>% count(medium) %>% print()

# --- Generate detections ------------------------------------------------------

generate_detections <- function(sites, sampling_events, chemical_portfolio,
                                method_coverage, partitioning,
                                media_applicability) {

  # Cross sampling events with chemicals, then filter by:
  #   - method_coverage (was the method run that year for this medium?)
  #   - media_applicability (does this analyte make sense in this medium?)
  #   - analyte-level filters for fish tissue & air

  base <- sampling_events %>%
    left_join(sites %>% select(site_id, river_km, dist_nearest_discharge_km),
              by = "site_id")

  detections <- base %>%
    cross_join(chemical_portfolio) %>%
    # Analyte-level applicability for selective media
    filter(
      !(medium == "fish_tissue" & domain == "Metals" & !analyte %in% fish_tissue_metals),
      !(medium == "fish_tissue" & domain == "SVOCs"  & !analyte %in% fish_tissue_svocs),
      !(medium == "air"         & domain == "PFAS"   & !analyte %in% air_pfas),
      !(medium == "air"         & domain == "VOCs"   & analyte == "Oil & Grease")
    ) %>%
    # Domain-level applicability per medium
    inner_join(media_applicability %>% filter(applicable) %>% select(medium, domain),
               by = c("medium","domain")) %>%
    # Method coverage gate
    inner_join(
      method_coverage %>% filter(method_available == 1) %>%
        select(site_id, medium, year, domain),
      by = c("site_id","medium","year","domain")
    ) %>%
    # Spatial / temporal / seasonal factors (same logic as original, with
    # medium-specific tweaks)
    mutate(
      spatial_factor = case_when(
        detection_class == "discharge_driven" ~ exp(-0.15 * dist_nearest_discharge_km),
        detection_class == "ubiquitous"       ~ pmax(0.3, 1 - 0.02 * dist_nearest_discharge_km),
        detection_class == "rare_hit"         ~ exp(-0.25 * dist_nearest_discharge_km) * 0.15,
        TRUE ~ 0.5
      ),
      year_centered = year - 2018,
      temporal_factor = case_when(
        domain == "PFAS" & year <= 2020 ~ 1 + 0.05 * year_centered,
        domain == "PFAS" & year > 2020  ~ 1.1 - 0.03 * (year - 2020),
        domain == "VOCs" ~ 1 - 0.02 * year_centered,
        domain == "Metals" ~ 1 + rnorm(n(), 0, 0.02),
        domain == "Radionuclides" &
          radionuclide_interest_window == "short_term" &
          detection_class == "rare_hit" ~
          if_else(year %in% c(2014, 2019, 2023) & month %in% 3:8, 1.8, 0.35),
        domain == "Radionuclides" &
          radionuclide_interest_window == "short_term" ~
          0.9 + rnorm(n(), 0, 0.05),
        domain == "Radionuclides" &
          radionuclide_interest_window == "long_term" ~
          1 + 0.01 * year_centered + rnorm(n(), 0, 0.03),
        TRUE ~ 1
      ),
      temporal_factor = pmax(0.1, temporal_factor),
      seasonal_factor = case_when(
        medium == "surface_water" & domain %in% c("VOCs","SVOCs") ~
          1 + 0.2 * sin(2 * pi * (month - 3) / 12),
        medium == "surface_water" & domain == "WQ_Metrics" & analyte == "Temperature" ~
          1 + 0.4 * sin(2 * pi * (month - 3) / 12),
        medium == "surface_water" & domain == "WQ_Metrics" & analyte == "Dissolved Oxygen" ~
          1 - 0.15 * sin(2 * pi * (month - 3) / 12),
        # Sediment/soil are integrated (less seasonal)
        medium %in% c("sediment","soil") ~ 1 + rnorm(n(), 0, 0.05),
        # Fish tissue: lipid content cycles, modest seasonal effect
        medium == "fish_tissue" ~ 1 + 0.1 * sin(2 * pi * (month - 6) / 12),
        # Air: VOCs higher in summer (volatilization)
        medium == "air" & domain == "VOCs" ~ 1 + 0.3 * sin(2 * pi * (month - 7) / 12),
        TRUE ~ 1 + rnorm(n(), 0, 0.05)
      ),
      # Medium-specific detection probability multiplier
      # Solids/tissue tend to integrate signal -> higher detection rates for
      # bioaccumulators, but require the chemical to actually partition there.
      medium_detect_mult = case_when(
        medium == "surface_water" ~ 1.0,
        medium == "groundwater" & domain == "Radionuclides" &
          analyte %in% c("Radon-222","Tritium","Technetium-99","Iodine-129") ~ 1.2,
        medium == "groundwater"   ~ 0.9,
        medium == "sediment" & domain %in% c("SVOCs","PFAS","Metals","Hydrocarbons") ~ 1.3,
        medium == "sediment" & domain == "Radionuclides" &
          radionuclide_interest_window == "long_term" ~ 1.2,
        medium == "sediment" & domain == "Radionuclides" &
          radionuclide_interest_window == "short_term" ~ 0.6,
        medium == "sediment" & domain == "VOCs" ~ 0.4,   # volatiles escape sediment
        medium == "sediment" ~ 1.0,
        medium == "soil" & domain %in% c("SVOCs","PFAS","Metals","Hydrocarbons") ~ 1.2,
        medium == "soil" & domain == "Radionuclides" &
          radionuclide_interest_window == "long_term" ~ 1.1,
        medium == "soil" & domain == "Radionuclides" &
          radionuclide_interest_window == "short_term" ~ 0.5,
        medium == "soil" & domain == "VOCs" ~ 0.3,
        medium == "soil" ~ 0.9,
        medium == "fish_tissue" & domain == "PFAS" ~ 1.4,  # bioaccumulates
        medium == "fish_tissue" & analyte == "Mercury" ~ 1.5,
        medium == "fish_tissue" ~ 0.8,
        medium == "air" & domain == "VOCs" ~ 1.2,
        medium == "air" ~ 0.6,
        TRUE ~ 1.0
      ),
      detect_prob = pmin(0.97, spatial_factor * temporal_factor * medium_detect_mult * 0.7),
      detect_prob = if_else(domain == "WQ_Metrics", 1.0, detect_prob),
      detected = rbinom(n(), 1, detect_prob)
    ) %>%
    # Join partitioning for media transformation
    left_join(partitioning, by = c("domain","medium")) %>%
    # Fall back gracefully if a (domain,medium) row is missing in partitioning
    mutate(
      log_partition_mu = coalesce(log_partition_mu, 0),
      log_partition_sd = coalesce(log_partition_sd, 0.3),
      reported_units   = case_when(
        medium %in% c("surface_water","groundwater") ~ units.x,
        TRUE ~ coalesce(units.y, units.x)
      ),
      log_conc_mean = log(typical_conc_ug_l) +
        log(spatial_factor) +
        log(temporal_factor) +
        log(pmax(0.5, seasonal_factor)) +
        log_partition_mu,
      log_conc_sd = sqrt(0.5^2 + log_partition_sd^2),
      concentration = if_else(
        detected == 1,
        exp(rnorm(n(), log_conc_mean, log_conc_sd)),
        NA_real_
      ),
      # Medium-specific reporting limits (rough scale relative to typical conc
      # in the new units after partitioning)
      rl_scale = case_when(
        medium == "surface_water" ~ 0.10,
        medium == "groundwater"   ~ 0.10,
        medium == "sediment"      ~ 0.05,   # solids RLs typically lower relative to typical conc
        medium == "soil"          ~ 0.05,
        medium == "fish_tissue"   ~ 0.08,
        medium == "air"           ~ 0.15,
        TRUE ~ 0.10
      ),
      typical_in_medium = exp(log(typical_conc_ug_l) + log_partition_mu),
      reporting_limit = typical_in_medium * runif(n(), rl_scale * 0.5, rl_scale * 2),
      result_qualifier = if_else(detected == 1, "", "U"),
      reported_result  = if_else(detected == 1, concentration, reporting_limit)
    ) %>%
    select(
      event_sample_id, sample_id, site_id, site_type, medium,
      sample_date, year, month,
      analyte_id, analyte, cas, domain, family, order,
      half_life_days, radionuclide_interest_window,
      reported_units,
      detected, concentration, reporting_limit,
      result_qualifier, reported_result,
      dist_nearest_discharge_km
    )

  return(detections)
}

cat("\nGenerating detections (this may take a moment)...\n")
detections <- generate_detections(sites, sampling_events, chemical_portfolio,
                                  method_coverage, partitioning,
                                  media_applicability)

cat("Total records:", nrow(detections), "\n")
cat("Detections:", sum(detections$detected, na.rm = TRUE), "\n")
cat("Detection rate:", round(mean(detections$detected, na.rm = TRUE), 3), "\n")

# --- Bioassay -----------------------------------------------------------------
# Run AhR on surface water (whole-water) and on sediment porewater extracts.

bioassay <- detections %>%
  filter(medium %in% c("surface_water","sediment"),
         domain %in% c("VOCs","SVOCs","Hydrocarbons","PFAS")) %>%
  group_by(sample_id, site_id, site_type, medium, sample_date, year, month,
           dist_nearest_discharge_km) %>%
  summarise(
    n_organic_detects   = sum(detected, na.rm = TRUE),
    total_organic_conc  = sum(concentration, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(
    log_burden = log1p(total_organic_conc),
    ahr_fold_induction = pmax(
      0.8,
      1.0 + 0.3 * log_burden + rnorm(n(), 0, 0.8) +
        if_else(medium == "sediment", 0.5, 0)   # sediment extracts often higher
    ),
    site_random = rnorm(n(), 0, 0.3)[match(site_id, unique(site_id))],
    ahr_fold_induction = pmax(0.5, ahr_fold_induction + site_random),
    ahr_significant = ahr_fold_induction > 1.5,
    ahr_qc_flag = sample(c("Pass","Pass","Pass","Flag-matrix"), n(), replace = TRUE),
    bioassay_matrix = if_else(medium == "sediment", "porewater_extract", "whole_water")
  ) %>%
  select(sample_id, site_id, site_type, medium, bioassay_matrix,
         sample_date, year, month, dist_nearest_discharge_km,
         n_organic_detects, total_organic_conc,
         ahr_fold_induction, ahr_significant, ahr_qc_flag)

cat("\nBioassay summary:\n")
bioassay %>% count(medium) %>% print()

# --- Denormalize to a single self-contained detections table -----------------
# Join site geography, chemical reference info, the method name appropriate to
# each medium, and the bioassay result for the parent sample. This produces a
# single fact table that does not require any of the dimension lookups to use.

# Long-form method names: one row per (domain, medium) with the right method.
method_names_long <- method_domains %>%
  pivot_longer(
    cols = starts_with("method_name_"),
    names_to = "matrix_class_raw",
    values_to = "method_name"
  ) %>%
  mutate(
    matrix_class_raw = str_remove(matrix_class_raw, "^method_name_"),
    medium = case_when(
      matrix_class_raw == "water"  ~ list(c("surface_water","groundwater")),
      matrix_class_raw == "solid"  ~ list(c("sediment","soil")),
      matrix_class_raw == "tissue" ~ list("fish_tissue"),
      matrix_class_raw == "air"    ~ list("air")
    )
  ) %>%
  unnest(medium) %>%
  filter(!is.na(method_name)) %>%
  select(domain, medium, method_name)

# Build the final denormalized table.
detections_full <- detections %>%
  # Site geography
  left_join(
    sites %>% select(site_id, river_km, lat, lon,
                     dist_discharge_1_km, dist_discharge_2_km),
    by = "site_id"
  ) %>%
  # Chemical reference (water-phase typical conc, kept as a reference column
  # — the row's own concentration is in the per-medium reported_units)
  left_join(
    chemical_portfolio %>% select(analyte_id, typical_conc_ug_l, detection_class),
    by = "analyte_id"
  ) %>%
  # Method name for this (domain, medium)
  left_join(method_names_long, by = c("domain","medium")) %>%
  # Bioassay (only present for surface_water and sediment events)
  left_join(
    bioassay %>%
      select(sample_id, sample_date,
             ahr_fold_induction, ahr_significant, ahr_qc_flag,
             bioassay_matrix),
    by = c("sample_id","sample_date")
  ) %>%
  # Reorder columns: identifiers, site geo, sample/event, analyte, result, qc, bioassay
  select(
    # identifiers
    event_sample_id, sample_id, site_id, site_type,
    # site geography
    river_km, lat, lon,
    dist_nearest_discharge_km, dist_discharge_1_km, dist_discharge_2_km,
    # event
    medium, sample_date, year, month,
    # analyte
    analyte_id, analyte, cas, domain, family, order,
    detection_class, typical_conc_ug_l,
    half_life_days, radionuclide_interest_window,
    # method
    method_name,
    # result
    reported_units, detected, concentration, reporting_limit,
    result_qualifier, reported_result,
    # bioassay (parent sample)
    bioassay_matrix, ahr_fold_induction, ahr_significant, ahr_qc_flag
  )

# --- Write output -------------------------------------------------------------

output_dir <- file.path(here::here("data", "benchmark"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

write_csv(detections_full, file.path(output_dir, "detections.csv"))

set.seed(4242)
detections_quick_test <- detections_full %>%
  group_by(analyte_id, analyte) %>%
  mutate(.quick_test_random = runif(n())) %>%
  arrange(.quick_test_random, .by_group = TRUE) %>%
  slice_head(n = quick_test_n_per_compound) %>%
  ungroup() %>%
  select(-.quick_test_random)

write_csv(
  detections_quick_test,
  file.path(output_dir, "detections_quick_test_20_per_compound.csv")
)

# --- Summary ------------------------------------------------------------------

cat("\n========================================\n")
cat("Multimedia Dataset Summary (single-file)\n")
cat("========================================\n")
cat("Sites:", nrow(sites), "\n")
cat("Analytes:", nrow(chemical_portfolio), "\n")
cat("Media:", paste(media$medium, collapse = ", "), "\n")
cat("Sampling events:", nrow(sampling_events), "\n")
cat("Total analytical records:", nrow(detections_full), "\n")
cat("Quick-test records:", nrow(detections_quick_test), "\n")
cat("  ...with bioassay attached:",
    sum(!is.na(detections_full$ahr_fold_induction)), "\n")
cat("Columns in detections.csv:", ncol(detections_full), "\n\n")

cat("Detection rates by medium x domain:\n")
detections_full %>%
  group_by(medium, domain) %>%
  summarise(n = n(),
            detect_rate = round(mean(detected), 3),
            .groups = "drop") %>%
  pivot_wider(names_from = domain, values_from = detect_rate) %>%
  print(n = Inf)

cat("\nRecord counts by medium:\n")
detections_full %>% count(medium) %>% print()

cat("\nFile written to:", file.path(output_dir, "detections.csv"), "\n")
cat("Quick-test file written to:",
    file.path(output_dir, "detections_quick_test_20_per_compound.csv"), "\n")
