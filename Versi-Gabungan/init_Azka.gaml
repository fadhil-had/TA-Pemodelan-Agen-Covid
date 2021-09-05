/**
* Name: Model4
* Based on the internal empty template. 
* Author: Prince
* Tags: 
*/


model tugasAkhirAzka

import "agen_Azka.gaml"
import "parameter_Azka.gaml"
import "reflex_global_Azka.gaml"

/* Insert your model definition here */

global {
	date cur_date <- #now;
	string cur_date_str <- replace(string(cur_date),':','-');
	int hours_elapsed <- 0 update: hours_elapsed + 1;
	int current_hour <- 0 update: (hours_elapsed) mod 24;
	int current_day_of_week <- 0 update: ((hours_elapsed) div 24) mod 7;
	string hari_apa <- int_to_day(current_day_of_week) update: int_to_day(current_day_of_week);
	int current_day <- 0 update: ((hours_elapsed) div 24);
	int previous_day <- 0;	
	
	string int_to_day (int x) {
		string str;
		switch x {
			match 0 {str <- "Senin";}
			match 1 {str <- "Selasa";}
			match 2 {str <- "Rabu";}
			match 3 {str <- "Kamis";}
			match 4 {str <- "Jumat";}
			match 5 {str <- "Sabtu";}
			match 6 {str <- "Minggu";}
		}
		return str;
	}
	
	//Initial Shapefile from GIS
	file shp_boundary <- file("../includes/Peta/Peta_Surabaya.shp"); //Data from GIS
	file shp_buildings <- file("../includes/Bangunan/Surabaya.shp"); //Data from GIS
	geometry shape <- envelope(shp_buildings); //Data from GIS
	file shp_roads <- file("../includes/Jalan/Jalan_Surabaya.shp"); //Data from GIS
	
	map<string, list<Building>> buildings_per_activity;
	// map memetakan jenis bangunan ke semua bangunan yang sesuai.
	map<string, list<Individual>> individuals_per_profession;
	// map untuk mengelompokkan Individual dengan profesinya, ada maupun tidak.
	list<string> possible_livings;
	// list akan diisi jenis bangunan apa saja yang dianggap sebagai rumah.
	list<Building> livings;
	// list akan diisi semua entitas Bangunan yang digolongkan rumah.
	list<Building> homes;
	// list untuk fungsi among
	map<list<int>,string> possible_schools;
	// map akan memetakan rentang usia dengan jenis pendidikan yang sesuai.
	map<string, float> possible_worktype;
	// map untuk memetakan jenis pekerjaan dengan peluangnya.
	list<string> possible_markets;
	// list akan diisi dengan semua jenis bangunan yang dapat digunakan untuk belanja.
	// untuk major agenda ibu rumah tangga
	list<string> possible_minors;
	// list akan diisi dengan semua jenis bangunan yang menjadi tempat minor agenda.
	map<string, float> possible_pns;
	map<string, float> possible_swasta;
	map<string, float> possible_bumn;
	map<string, float> possible_wiraswasta;
	map<string, float> possible_nakes;
	int total_hospital;
	list<Individual> population;
	list<Building> hospitals;
	
	//Action for Initial from GIS
	action init_building {
	// Action untuk membuat entitas Boundary, Roads, dan Building.
		create Boundary from: shp_boundary;
		create Roads from: shp_roads;
		create Building from: shp_buildings with: [type:: read("building")];
	}
	
	action init_jobtype {
		// Action untuk memasukkan tiap type building ke kategori masing-masing
		buildings_per_activity <- Building group_by (each.type);
		possible_livings <- ["house","hotel","apartments"];
		livings <- Building where (each.type in ["apartments","hotel"]);
		homes <- Building where (each.type in ["house"]);
		possible_schools <-  [[4,5]::"kindergarten", [6,11]::"elementary_school", [12,14]::"junior_high_school", [15,17]::"senior_high_school", [18,24]::"university"];
		possible_markets <- ["marketplace","mall","store"];
		possible_minors <- ["cafe","temple","public","mosque","church","marketplace","mall","store"];
		possible_worktype <- ["pns"::0.0232, "police"::0.0081, "swasta"::0.7715, "bumn"::0.034, "nakes"::0.0058, "wiraswasta"::0.1561, "guru"::0.0165, "industrial"::0.0154];
		possible_pns <- ["village_office"::0.25, "subdistrict_office"::0.05, "government_office"::0.7];
		possible_bumn <- ["post_office"::0.1, "bank"::0.6, "community_group_office"::0.3];
		possible_wiraswasta <- ["store"::0.4, "marketplace"::0.6];
		possible_swasta <- ["embassy"::0.001, "commercial"::0.14, "office"::0.7, "mall"::0.119, "cafe"::0.04];
		possible_nakes <- ["clinic"::0.1, "hospital"::0.9];	
		hospitals <- Building where(each.type="hospital");
	}
	
	action population_generation {
	/*
	 * Action untuk membuat populasi entitas Individual.
	 * Melibatkan penentuan bangunan rekreasi. Tiap anggota keluarga memiliki jenis rekreasi persis.
	 * Kemudian keluarga dibentuk dengan probabilitas-probabilitas di parameters.gaml.
	 * Dalam action ini ditentukan atribut-atribut seperti usia, jenis kelamin, komorbiditas, rumah,
	 * dan bangunan rekreasi.
	 */
	 
	 	int num_family_homes <- num_family;
		ask num_family_homes among homes {
			
			if (flip(proba_active_family)) {
				// Keluarga aktif didefinisikan sebagai keluarga yang setidaknya ada ayah dan ibu.
				
				create Individual {
					age <- rnd(min_working_age,max_working_age);
					sex <- 1;
					home <- myself;
					myself.residents << self;
				}
				
				create Individual {
					age <- rnd(min_working_age,max_working_age);
					sex <- 0;
					home <- myself;
					myself.residents << self;
				}
				
				int num_children <- rnd(0,max_num_children);
				loop times: num_children {
					create Individual {
						age <- rnd(min_age,max_student_age);
						sex <- rnd(0,1);
						home <- myself;
						myself.residents << self;
					}
				}
				
				loop times: rnd(1,3) { 
					if(flip(proba_others)) {//ini coba di loop buat naikin jumlah penduduk
						create Individual {
							age <- rnd(min_working_age,max_working_age);
							sex <- rnd(0,1);
							home <- myself;
							myself.residents << self;
						}
					}
				}
			} else {
				// Individual yang tinggal sendirian
				
				create Individual {
					age <- rnd(min_working_age,max_age);
					sex <- rnd(0,1);
					home <- myself;
					myself.residents << self;
				}
			}			
		}
		/* 
		ask livings {
			
			int num_apart_family <- (num_family div 10) div 12;
			loop times: num_apart_family {
				if (flip(proba_active_family)) {
					// Keluarga aktif didefinisikan sebagai keluarga yang setidaknya ada ayah dan ibu.
				
					create Individual {
						age <- rnd(min_working_age,max_working_age);
						sex <- 1;
						home <- myself;
						myself.residents << self;
					}
				
					create Individual {
						age <- rnd(min_working_age,max_working_age);
						sex <- 0;
						home <- myself;
						myself.residents << self;
					}
				
					int num_children <- rnd(0,max_num_children);
					loop times: num_children {
						create Individual {
							age <- rnd(min_age,max_student_age);
							sex <- rnd(0,1);
							home <- myself;
							myself.residents << self;
						}
					}
				
					if(flip(proba_others)) {
						create Individual {
							age <- rnd(min_working_age,max_working_age);
							sex <- rnd(0,1);
							home <- myself;
							myself.residents << self;
						}
					}
				
					} else {
						// Individual yang tinggal sendirian
				
						create Individual {
							age <- rnd(min_working_age,max_age);
							sex <- rnd(0,1);
							home <- myself;
							myself.residents << self;
						}
					}			
				}
			}
	*/	
			num_population <- length (Individual);
			population <- Individual where (each.stat_traveler = "none" or each.stat_traveler = "leave");
		}
	
	action major_agenda{
		ask Individual {
			do enter_building(home);
			if (age >= min_student_age and age <= min_working_age-1) {
				list<int> L <- match_age(possible_schools.keys);
				string temp <- possible_schools[L];
				list<Building> schools <- buildings_per_activity[temp];
				major_agenda_place <- schools closest_to self;
				major_agenda_place.residents << self;
				major_agenda_type <- "school";
			}
			else if (age >= 15 and age <= 19) {
				if flip(proba_15_school) {
					list<int> L <- match_age(possible_schools.keys);
					string temp <- possible_schools[L];
					list<Building> schools <- buildings_per_activity[temp];
					major_agenda_place <- schools closest_to self;
					major_agenda_place.residents << self;
					major_agenda_type <- "school";
				}
				else {
					if (sex=0){
						is_employed <- flip(proba_employed_male);
					}
					else {
						is_employed <- flip(proba_employed_female);
					}
				}
			}
			else if (age>19 and age<=24){
				if flip(proba_19_school) {
					list<int> L <- match_age(possible_schools.keys);
					string temp <- possible_schools[L];
					list<Building> schools <- buildings_per_activity[temp];
					major_agenda_place <- schools closest_to self;
					major_agenda_place.residents << self;
					major_agenda_type <- "school";
				}
				else {
					if (sex=0){
						is_employed <- flip(proba_employed_male);
					}
					else {
						is_employed <- flip(proba_employed_female);
					}
				}
			}
			else if (age>24 and age<=max_working_age){
				if (sex=0){
					is_employed <- flip(proba_employed_male);
				}
				else {
					is_employed <- flip(proba_employed_female);
				}
			}
			else {
				is_employed <- false;
			} 
			list<Building> working_places;
			// Buat status pekerjaan
			if (is_employed){
				major_agenda_type <- rnd_choice(possible_worktype);
				if (major_agenda_type = "guru"){
					string school_place <- one_of(possible_schools.values);
					working_places <- buildings_per_activity[school_place];
				}
				else if (major_agenda_type = "pns"){
					string pns_place <- rnd_choice(possible_pns);
					working_places <- buildings_per_activity[pns_place];
				}
				else if (major_agenda_type = "bumn"){
					string bumn_place <- rnd_choice(possible_bumn);
					working_places <- buildings_per_activity[bumn_place];
				}
				else if (major_agenda_type = "wiraswasta"){
					string wiraswasta_place <- rnd_choice(possible_bumn);
					working_places <- buildings_per_activity[wiraswasta_place];
				}
				else if (major_agenda_type = "swasta"){
					string swasta_place <- rnd_choice(possible_bumn);
					working_places <- buildings_per_activity[swasta_place];
				}
				else if (major_agenda_type = "nakes"){
					string nakes_place <- rnd_choice(possible_nakes);
					working_places <- buildings_per_activity[nakes_place];
				}
				else {
					working_places <- buildings_per_activity[major_agenda_type];
				}
				major_agenda_place <- one_of(working_places);
				major_agenda_place.residents << self;
			}
			else {
				major_agenda_type <- "none";
				major_agenda_place <- home;
			}		
		}
	total_hcw <- population count (each.major_agenda_type in "nakes");
	}
	
	
	action assign_major_agenda {
		ask Individual {
			// inisiasi list agenda
			loop i from: 0 to: 6 {
				agenda_week << [];
			}
			
			// membagi agenda untuk siswa/mahasiswa
			if (major_agenda_type = "school") {
				list<int> L <- match_age(possible_schools.keys);
				string temp <- possible_schools[L];
				loop d over: [0,1,2,3,4] {
					int start_hour;
					int end_hour;
					// Penentuan jam masuk dan pulang untuk setiap jenis sekolah.
					switch temp {
						match "kindergarten" {
							start_hour <- 7;
							end_hour <- 10;
						}
						match "elementary_school" {
							start_hour <- 7;
							end_hour <- 13;
						}
						match "junior_high_school" {
							start_hour <- 7;
							end_hour <- 15;
						}
						match "senior_high_school" {
							start_hour <- 7;
							end_hour <- 15;
						}
						match "university" {
							start_hour <- rnd(7,12);
							end_hour <- rnd(14,18);
						}
					}
					major_agenda_hours[d] <- [start_hour, end_hour];
					(agenda_week[d])[start_hour] <- self.major_agenda_place;
					(agenda_week[d])[end_hour] <- self.home;
							
				}
			} 
			else if (major_agenda_type in  ["wiraswasta", "industrial"]) {
				// Penetapan jam kerja dan pulang untuk wiraswasta dan buruh industrial				
				// inisiasi list hari kerja
				list<int> working_days <- [];
				loop i over: [0,1,2,3,4,5,6] {
					working_days << i;
				}
				// Sebanyak n (1-4) hari kerja dibuang secara random dari semua hari kerja
				int n <- rnd(1, 3);
				loop x from: 0 to: n{
					int i <- one_of(working_days);
					working_days >> i;
				}					
				// Penetapan jam kerja dan pulang
				loop d over: working_days {
					int start_hour <- rnd (7,10);
					int end_hour <- rnd(16,21);
					major_agenda_hours[d] <- [start_hour, end_hour];
					(agenda_week[d])[start_hour] <- self.major_agenda_place;
					(agenda_week[d])[end_hour] <- self.home;
				}
			}
			else {
				// Penetapan jam kerja untuk pekerja kantoran
				if (major_agenda_type != "none") {
					loop d over: [0,1,2,3,4] {
						int start_hour <- rnd(7,10);
						int end_hour <- rnd(15,19);
						major_agenda_hours[d] <- [start_hour, end_hour];
						agenda_week[d][start_hour] <- self.major_agenda_place;
						agenda_week[d][end_hour] <- self.home;
					}
				}
				
			}
		}
	}
	
	action init_hospital{
		total_hospital <- Building count (each.type in "hospital");
		int temp_patient <- int(patient_cap div total_hospital);
		int temp_icu <- int(icu_cap div total_hospital);
		int temp_ven <- int(ven_cap div total_hospital);
		
		ask hospitals{
			patient_capacity <- temp_patient;
			icu_capacity <- temp_icu;
			icu_venti_capacity <- temp_ven; 
		}
		
		if ((patient_cap mod total_hospital)!=0 or (icu_cap mod total_hospital)!=0 or (ven_cap mod total_hospital)!=0){
			int temp_patient1 <- patient_cap mod total_hospital;
			int temp_icu1 <- icu_cap mod total_hospital;
			int temp_ven1 <- ven_cap mod total_hospital;
			
			ask one_of(hospitals){
				patient_capacity <- temp_patient + temp_patient1;
				icu_capacity <- temp_icu + temp_icu1;
				icu_venti_capacity <- temp_ven + temp_ven1; 
			}
		}
	}
	
}