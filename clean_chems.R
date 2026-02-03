library(tidyverse)
library(ComptoxR)

uncurated_chemicals <- read_csv(
  "uncurated_chemicals_2023-05-16_12-43-41.csv", 
	col_types = 'ccc'
) %>%
  distinct(raw_cas, raw_chem_name) %>%
  mutate(idx = 1:n(), .before = raw_cas)

validation <- rio::import(
  'cleaned_chemicals_for_curation-Jul-03-2023.xlsx'
)

pre_cleaned <- uncurated_chemicals %>%
  mutate(
    raw_chem_name = str_remove_all(raw_chem_name, pattern = '\\r'),
    raw_cas = str_remove_all(raw_cas, "\\r"),
    mix_chk = extract_mixture(raw_chem_name),
    mult_cas = extract_cas(raw_cas),
    form_chk = extract_formulas(raw_chem_name)
  ) %>% 
unnest_longer(., col = mult_cas, keep_empty = TRUE) %>% unnest_longer(., col = form_chk, keep_empty = TRUE) %>% 
mutate(
	cas_chk = is_cas(mult_cas)
)

janitor::get_dupes(pre_cleaned, idx) %>% View()

cas <- pre_cleaned %>% 
	pull(mult_cas) %>% 
	unique() %>%
	chemi_resolver(query = .) %>% 
	filter(result == 'FOUND') %>% 
	select(
		raw_query,
		dtxsid_cas = dtxsid, 
		casrn_cas = casrn,
		name_cas = name
	)

names <- pre_cleaned %>% 
	pull()

cleaned <- pre_cleaned

	
