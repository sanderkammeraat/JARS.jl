
using JARS

base_folder = "/Users/kammeraat/mounting/alicedata1_kammeraatsc1/jamming/exploration/pf_sweep_test/"

ap, rp, sp = JIO.auto_analysis_dir(base_folder, "sa_raw_data.h5",support_raw_data_file_name_pattern= "ra_raw_data.h5")

analyze_single(cf, ap, rp, support_raw_data_file_path=sp)