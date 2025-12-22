
q1 <- uncurated_chemicals %>% 
  mutate(
    idx = 1:n(), .before = 'raw_cas') %>% 
  #removes empty rows
  filter(
    if_any(everything(), ~ !is.na(.))
  ) %>% 
 mutate(
    cas_in_name = str_extract_all(raw_chem_name, "[1-9][0-9]{1,6}\\-[0-9]{2}\\-[0-9]", simplify = FALSE),
    formula = str_extract_all(raw_chem_name, final_regex)
) %>% 
  unnest_longer(., col = cas_in_name:formula, keep_empty = T) 
  

q1[3031,]


#extract + flag for matches
#run checks on things like casrn
#add qc notes