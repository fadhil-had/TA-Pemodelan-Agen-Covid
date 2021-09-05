/**
* Name: tugasAkhir
* Based on the internal empty template. 
* Author: Azka
* Tags: 
*/


model tugasAkhirAzka

import "init_Azka.gaml"
import "parameter_Azka.gaml"

/* Insert your model definition here */

species Individual {
	//------------------------//
	//-- Atribut individual --//
	//------------------------//
	
	// Atribut umum
	int live <- 1; //Status kehidupan agen
	int age; //Umur
	int sex; //Jenis kelamin, 0 male 1 female
	float proba_travel <- 0.01; //Kemungkinan orang melakukan perjalanan
	string stat_traveler <- "none"; //Status pelaku perjalanan, dibagi 4 yaitu none, commuter, leave and come
	int traveler_days <- 0;
	int max_travel_days <- rnd(7,21);
	string job; //Jenis pekerjaan
	Building current_place; //Tempat saat ini
	Building home; //Rumah agen
	Building test_place;
	
	// Atribut Agenda
	bool is_employed;
	string major_agenda_type;
	Building major_agenda_place;
	list<map<int, Building>> agenda_week;
	map<int,list<int>> major_agenda_hours;
	
	// Atribut Klinis
	//int comorbid; //Jenis komorbid
	string stat_covid <- "normal"; //Status Covid
	string severity; //Keparahan Covid, muncul setelah fix Covid
	string covid_stat <- "none"; //Untuk melihat secara pasti seseorang Covid atau bukan
	bool quarantine_status <- false;
	int infection_period <- 0;
	int incubation_period <- 0; //Masa inkubasi menuju timbul gejala
	int quarantine_period <- 0; //Masa karantina
	int death_recovered_period <- 0;
	int illness_period <- 0;
	float death_proba <- 0.02; //Kemungkinan mati
	string symptomps; //Gejala awal sebelum pasti Covid
	bool must_rapid_test <- false; //Status wajib test jika kena contact trace
 	bool must_PCR_test <- false; //Status wajib test jika kena contact trace
 	int PCR_dayafter_count <- 0; //Hitungan berapa jumlah sudah test PCR
 	bool have_PCR; //Status apakah sudah PCR
 	int PCR_waiting_day; //Hari menunggu hasil PCR
	int rapid_result <- 0; //1 positif, 2 negatif
	int pcr_result <- 0;
	int type_of_death; // 0 normal, 1 confirmed, 2 probable
	list<Individual> meet_today; //Untuk melihat yang ditemui di hari ini
	list<Individual> meet_yesterday; //Untuk melihat yang ditemui di kemaren 
	Building quarantine_place;
	string s_quarantine_place;
	bool must_go_home;
	bool icu_venti;
	int temp_count;
	
	
	// Action Individual Umum
	
	// 1. Action masuk kedalam bangunan
	action enter_building(Building b){
		if (current_place != nil) {
			current_place.Individuals_inside >> self;
		}
		current_place <- b;
		current_place.Individuals_inside << self;
		location <- any_location_in (current_place);
	}
	
	// 2. Action assign agenda minor
	action assign_agenda(list<int> the_time) {
		
		int start <- rnd((min(the_time)),(max(the_time)-1));
		int end <- rnd(start+1,max(the_time));
		
		loop while: start > end {
			start <- rnd((min(the_time)),(max(the_time)-1));
			end <- rnd(start+1,max(the_time));
		}
		 
		agenda_week[current_day_of_week][start] <- one_of(Building where (each.type in possible_minors));
		agenda_week[current_day_of_week][end] <- home;
		
	}
	
	// Action Individual Klinis
	
	// 1. Action PCR Test (Real)
	action real_PCR { 
		//enter rumah sakit buat ambil hasil test
		if (live = 1){
			do enter_building(test_place);
		}
		
		if (covid_stat in ["infected"]) {
			bool test_result <- flip(sensitivity_pcr*test_accuracy);
			if (test_result) {// TRUE POSITIVE
				do contact_trace;
				stat_covid <- "confirmed";
				pcr_result <- 1;
				do contact_trace;
				if (quarantine_status=false){
					do init_quarantine;
				}
			}
			else { //FALSE NEGATIVE
				pcr_result <- 2;
			}
		}
		else {
			bool test_result <- flip(specificity_pcr*test_accuracy);
			if (test_result) { // real negative
				pcr_result <- 3;
			}
			else { //si yang sebenarnya negatif tp hasil tesnya positif
				stat_covid <- "confirmed";
				do contact_trace;
				do contact_trace;
				pcr_result <- 4;
				if (quarantine_status = false){
				do init_quarantine;
				}
			}
		}
	}
	
	// 2. Contact Trace
	action contact_trace {
		
		list<Individual> contacts <- self.home.residents - self; //Contact trace untuk penghuni rumah
			
		if (not (major_agenda_type in ["none"])) {
			contacts <- contacts + meet_today;
		}
		
		// Menentukan jumlah kontak yang gagal di-trace, berdasarkan tracing effectivity.
		int num_contacts_untraced <- round((1-contact_tracing_effectiveness)*length(contacts));
		loop times: num_contacts_untraced {
			contacts >> one_of(contacts);
		}
		
		//Mengubah status menjadi harus karantina, ga peduli karantina nya dimana
		if (contacts != []) {
			ask contacts {
				if (quarantine_status = false) {
					quarantine_status <- flip(obedience*quarantine_obedience);
					must_rapid_test <- true;
					stat_covid <- "suspect";
				}
			}
		}
	}
	
	// 3. Backward Contact Trace
	action contact_tracing_ps {
		list<Individual> contacts <- self.home.residents - self; //Contact trace untuk penghuni rumah
		temp_count <- 0;
		int contrac_count <- 0;
			
		if (not (major_agenda_type in ["none"])) {
			contacts <- contacts + meet_today;
		}
		
		if (contacts != []) {
			ask contacts {
				if (stat_covid in ["confirmed","probable"]) {
					contrac_count <- contrac_count + 1;
				}
			}
		}
		temp_count <- contrac_count;
	}
	
	// 4. Initiation Quarantine
	action init_quarantine{ 
		int temp<-1;
		quarantine_status <- true;
		
		if (severity in ["asymptom", "mild"]) { //Belum mempertimbangkan yang di pusat karantina (wisma haji)
			quarantine_place <- home;
			s_quarantine_place <- "home";
		}
		else if (severity in ["moderate"]){
			quarantine_place <- one_of(buildings_per_activity["hospital"]);
			loop while: (quarantine_place.patient_capacity = quarantine_place.patient_occupancy and temp <= total_hospital){
				quarantine_place <- one_of(buildings_per_activity["hospital"]); // selama kapasitas RS udah penuh, cari RS lain
				s_quarantine_place <- "hospital";
				temp <- temp+1;
			}
			
			//Jika semua RS penuh, maka karantina di rumah
			if temp>total_hospital {
				quarantine_place <- home;
				s_quarantine_place <- "home";
			}
			else {
				quarantine_place.patient_occupancy <- quarantine_place.patient_occupancy + 1;
			}
		}
		else if (severity in ["severe"]){
			loop while: (quarantine_place.icu_capacity = quarantine_place.icu_occupancy and temp <= total_hospital){
				quarantine_place <- one_of(buildings_per_activity["hospital"]); // selama kapasitas RS udah penuh, cari RS lain
				s_quarantine_place <- "ICU";
				temp <- temp+1;
			}
			
			//Jika semua ICU penuh, maka isolasi di kamar biasa di RS
			if temp > total_hospital {
				temp<-1;
				loop while: (quarantine_place.patient_capacity = quarantine_place.patient_occupancy and temp <= total_hospital){
					quarantine_place <- one_of(buildings_per_activity["hospital"]); // selama kapasitas RS udah penuh, cari RS lain
					s_quarantine_place <- "hospital";
					temp <- temp+1;
				}
				//Jika semua kamar biasa penuh, maka isolasi di rumah
				if temp > total_hospital {
					quarantine_place <- home;
					s_quarantine_place <- "home";
				}
				else {
					quarantine_place.patient_occupancy <- quarantine_place.patient_occupancy + 1;
				}
			}
			else {
				quarantine_place.icu_occupancy <- quarantine_place.icu_occupancy + 1;
			}
		}
		else { // severity = critical
			quarantine_place <- one_of(buildings_per_activity["hospital"]);
			loop while: (quarantine_place.icu_venti_capacity = quarantine_place.icu_venti_occupancy and temp <= total_hospital){
				quarantine_place <- one_of(buildings_per_activity["hospital"]); // selama kapasitas RS udah penuh, cari RS lain
				s_quarantine_place <- "ICU Venti";
				temp <- temp+1;
			}
			//Jika semua ICU Ventilator penuh, cari ICU biasa
			if temp > total_hospital {
				loop while: (quarantine_place.icu_capacity = quarantine_place.icu_occupancy and temp <= total_hospital){
					quarantine_place <- one_of(buildings_per_activity["hospital"]); // selama kapasitas RS udah penuh, cari RS lain
					s_quarantine_place <- "ICU";
					temp <- temp+1;
				}
			
				//Jika semua ICU penuh, maka isolasi di kamar biasa di RS
				if temp > total_hospital {
					temp<-1;
					loop while: (quarantine_place.patient_capacity = quarantine_place.patient_occupancy and temp <= total_hospital){
						quarantine_place <- one_of(buildings_per_activity["hospital"]); // selama kapasitas RS udah penuh, cari RS lain
						s_quarantine_place <- "hospital";
						temp <- temp+1;
					}
					//Jika semua kamar biasa penuh, maka isolasi di rumah
					if temp > total_hospital {
						quarantine_place <- home;
						s_quarantine_place <- "home";
					}
					else {
						quarantine_place.patient_occupancy <- quarantine_place.patient_occupancy + 1;
					}
				}
				else {
					quarantine_place.icu_occupancy <- quarantine_place.icu_occupancy + 1;
				}
			}
			else {
				quarantine_place.icu_venti_occupancy <- quarantine_place.icu_venti_occupancy + 1;
			}
		}
		do enter_building(quarantine_place);
		do death_proba_calculation;
	}
	
	// 5. Infection Parameters Initiation
	action init_infection {
		
		//Cek apakah dia asimptomp atau tidak
		list<int> l <- match_age(asymptomic_distribution.keys);
		float proba_asymptomic <- asymptomic_distribution[l];
		bool is_asymptomic <- flip(proba_asymptomic);
		
		//Cek apakah dia symptomic moderate
		l <- match_age(moderate_distribution.keys);
		float proba_moderate <- moderate_distribution[l];
		bool is_moderate <- flip(proba_moderate/(1-proba_asymptomic));
		
		// Menentukan tingkat keparahan: asimptomatik, ringan, sedang
		// atau sangat tinggi, berdasarkan probabilitas simptomatik,
		// probabilitas masuk rumah sakit, probabilitas masuk ICU, serta
		// probabilitas kematian.
		if (is_asymptomic) {
			if (is_moderate) {
				symptomps <- "moderate";
			} else {
				symptomps <- "mild";
			}
		} else {
			symptomps <- "asymptom";
		}
		
		// Menentukan kapan hari gejala timbul (sejak mulai terpapar hingga gejala muncul)
		l <- match_age(incubation_distribution.keys);
		incubation_period <- int(24*incubation_distribution[l]);
		
		// Menentukan penyakit tersebut berubah menjadi severity (sejak mulai terpapar hingga dapat dinyatakan positif)
		illness_period <- int(24*get_proba(days_diagnose, "normal")) + incubation_period;
		
		// Menentukan kapan hari sembuh (seluruh periode sakit)
		l <- match_age(days_symptom_until_recovered.keys);
		death_recovered_period <- int(24*get_proba(days_symptom_until_recovered[l], "normal")) + illness_period;
		
	}
	
	// 6. Death Proba Calculation
	action death_proba_calculation {
		if (severity = "asymptom"){
		
		}
		else if (severity = "mild") {
			
		}
		else if (severity = "moderate"){
			if (s_quarantine_place = "hospital"){
				
			}
			else{//house
				
			}
		}
		else if (severity = "severe"){
			if (s_quarantine_place = "ICU"){
				
			}
			else if (s_quarantine_place = "hospital"){
				
			}
			else{//house
				
			}
		}
		else {//severity = critical
			if (s_quarantine_place = "ICU Venti"){
				death_proba <- 0.4;
			}
			else if (s_quarantine_place = "ICU"){
				death_proba <- 0.4;
			}
			else if (s_quarantine_place = "hospital"){
				death_proba <- 0.5;
			}
			else{//house
				death_proba <- 0.7;
			}
		}
	}
	
	// 7. Delete from quarantine place
	action delete_qplace {
		if (s_quarantine_place = "ICU Venti") {
			quarantine_place.icu_venti_occupancy <- quarantine_place.icu_venti_occupancy - 1; 
		}
		if (s_quarantine_place = "ICU") {
			quarantine_place.icu_occupancy <- quarantine_place.icu_occupancy - 1; 
		}
		if (s_quarantine_place = "hospital") { 
			quarantine_place.patient_occupancy <- quarantine_place.patient_occupancy - 1; 
		}
	}
	
	// Reflex Individual Umum
	
	// 1. Reflex Bepergian atau Menjadi Traveler
	reflex the_traveler when : (current_hour = 20 and (flip(proba_travel) or stat_traveler="leave") and live = 1){ 
	//Jadi syarat orang traveler tu jam 8 malam sama proba
		if (traveler_days = 0) {
			Building s <- one_of(buildings_per_activity["train_station"]);
			do enter_building(s);
			stat_traveler <- "leave";
			traveler_days <- traveler_days + 1;
		}
		else if (traveler_days != max_travel_days) { //Kalau dia belum 7-21 hari, dia di stasiun dan akan stay
			traveler_days <- traveler_days + 1;
			}
		else {
			float mask_factor <- 1 - mask_effectiveness*mask_usage_proportion;
			float proba <- 0.0;
			
			if (covid_stat = "none"){
				list<int> l <- match_age(susceptibility.keys);
				proba <- get_proba(susceptibility[l],"gauss");
				proba <- proba * mask_factor * (1-infection_reduction_factor);
			}
			
			if (flip(proba)) {
				covid_stat <- "exposed";
				incubation_period <- 0;
			}
			
			stat_traveler <- "none";
			traveler_days <- 0;
			stat_covid <- "suspect";
			must_rapid_test <- true;
			do enter_building(home); //Kalau udah ya dipulangkan
			}
		}
	
	// 2. Reflex Kematian	
	reflex death when : (current_hour = 21 and live = 1){
		
		if (flip(death_proba)){
				live <- 0;
			}
		Building c <- one_of(buildings_per_activity["cemetary"]);
		if (stat_covid in ["normal","recovered","discarded"]){
			type_of_death <- 0;
			}	
		if (stat_covid = "confirmed"){
			type_of_death <- 1;
			stat_covid <- "death";
			}
		if (stat_covid in ["probable", "suspect"] and have_PCR = false){
			type_of_death <- 2;
			stat_covid <- "probable";
		}
		//Dikurangi dari okupansi RS
		if (quarantine_status) {
				do delete_qplace;
			}
		do enter_building(c);
			
	}
	
	// 3. Reflex Periksa Kematian Individu
	reflex probable_death_check when : (current_hour = 22 and live = 0 and have_PCR){
		Building c <- one_of(buildings_per_activity["cemetary"]);
		if (PCR_waiting_day = 0) {
			if (pcr_result in [1,4]) {
				type_of_death <- 1;
				stat_covid <- "death";
				}
			else {
				type_of_death <- 2;
				stat_covid <- "probable";
				}
			have_PCR <- false;
		}		
	}
	
	// 4. Reflex Menjalankan Agenda
	reflex execute_agenda when: (quarantine_status = false and stat_traveler != "leave" and live = 1) {
	//Kalau status karantina dan status bepergian tidak aktif	 
		map<int, Building> agenda_day <- agenda_week[current_day_of_week];
		if (agenda_day[current_hour] != nil) {
			do enter_building(agenda_day[current_hour]);
			if ((not (major_agenda_type in ["none"])) and current_hour = 7) {
				//Buat memastikan this function is only happen once a day
				meet_yesterday <- meet_today;
				meet_today <- self.major_agenda_place.residents - self;
			}
		}
	}
	
	// 5. Reflex Add Minor Agenda
	reflex minor_agenda when: ((current_hour = 0) and age >= min_student_age and age <= max_working_age and live = 1) {
		
		float proba_activity;
		list<int> start_end_hours <- major_agenda_hours[current_day_of_week];
		loop Time from: 0 to: length(time_of_day)-1 {
			if (((min(start_end_hours) > max(time_of_day[Time]))) or (max(start_end_hours) < min(time_of_day[Time]))) {
				proba_activity <- proba_activities[Time] * (1-activity_reduction_factor);
				if (flip(proba_activity)) {
					do assign_agenda(time_of_day[Time]);
				}
			}
		}		
	}
	
	// 6. Reflex Hapus Minor Agenda
	reflex remove_minor_agenda when: (current_hour = 23 and live = 1) {

		map<int, Building> agenda_day <- agenda_week[current_day_of_week];
		if (major_agenda_hours[current_day_of_week] != nil) {
			loop agenda over: agenda_day.keys {
				if (not (agenda in major_agenda_hours[current_day_of_week])) {
					remove key:agenda from: agenda_day;
				}
			}
		} else {
			loop agenda over: agenda_day.keys {
				remove key:agenda from: agenda_day;
			}
		}
	}
	
	// 7. Reflex Pulang ke Rumah
	reflex go_home when: (current_hour=7 and must_go_home=true){
		if (quarantine_status = false){
			do enter_building(home);
		}
		must_go_home <-  false;
	}
	
	
	// Reflex Individual Klinis
	
	// 1. Reflex Test Rapid
	reflex rapid_test when: (must_rapid_test and current_hour = 6 and live=1) {
		Building h <- one_of(buildings_per_activity["hospital", "clinic"]);
		do enter_building(h);
		rapid_result <- 0;
		
		if (covid_stat in ["infected"]) {
			bool test_result <- flip(sensitivity_rapid*test_accuracy); //Harus test rapid (Penting)
			if (test_result) {//true positive
				if (symptomps != "asymptom") {
					stat_covid <- "confirmed";
					do init_quarantine;
					do contact_trace;
				}
				else {
					do contact_tracing_ps;
					if (temp_count != 0){
						stat_covid <- "confirmed";
						do init_quarantine;
						do contact_trace;
						}
					else {
						must_PCR_test<-true;
						quarantine_status <- true;
						quarantine_place <- home;
						s_quarantine_place <- "home";
					}
				}
				rapid_result <- 1;
				do contact_trace;
			}
			else { //si yang sebenarnya positif tp hasil tesnya negatif
				if (symptomps in ["asymptom", "mild"]) {
					stat_covid <- "suspect";
					quarantine_status <- flip(obedience*quarantine_obedience);
					if (quarantine_status = true) {
						quarantine_place <- home;
						s_quarantine_place <- "home";
					}
				}
				else {
					stat_covid <- "probable";
					quarantine_status <- true;
					quarantine_place <- home;
					s_quarantine_place <- "home";
					must_PCR_test <- true;
				}
				rapid_result <- 2;
			}
		}
		else {
			bool test_result <- flip(specificity_rapid*test_accuracy);
			if (test_result) {
				if (symptomps in ["asymptom", "mild"]) {
					stat_covid <- "suspect";
					quarantine_status <- flip(obedience*quarantine_obedience);
					if (quarantine_status = true) {
						quarantine_place <- home;
						s_quarantine_place <- "home";
					}
				}
				else {
					stat_covid <- "probable";
					quarantine_status <- true;
					quarantine_place <- home;
					s_quarantine_place <- "home";
					must_PCR_test <- true;
				}
				rapid_result <- 3;
			}
			else { //si yang sebenarnya negatif tp hasil tesnya positif
				if (symptomps != "asymptom") {
					stat_covid <- "confirmed";
					do init_quarantine;
					do contact_trace;
				}
				else {
					do contact_tracing_ps;
					if (temp_count != 0){
						stat_covid <- "confirmed";
						do init_quarantine;
						do contact_trace;
						}
					else {
						must_PCR_test<-true;
						quarantine_status <- true;
						quarantine_place <- home;
						s_quarantine_place <- "home";
					}
				}
				rapid_result <- 4;
				do contact_trace;
			}
		}
		if (quarantine_status=false) {
			must_go_home <- true;
		}
	} 

	
	// 2. Reflex PCR Test (Inisiasi)
	reflex pcr_test when: (must_PCR_test and current_hour = 6) {
		if (PCR_waiting_day = 0) {
			pcr_result <- 0;
			have_PCR <- true;
			PCR_waiting_day <- PCR_waiting_day + 1;
			
			//enter building rs atau klinik
			Building h <- one_of(buildings_per_activity["hospital", "clinic"]);
			do enter_building(h);
			test_place <- h;
			if (quarantine_status = false){
				must_go_home <- true;
				}
			}
		else if (PCR_waiting_day =1) {
			PCR_waiting_day <- PCR_waiting_day + 1;
			}
		else {
			do real_PCR;
			PCR_waiting_day <- 0;
			must_PCR_test <- false;
			if (live = 1){
				have_PCR <- false;
			}
		} 
	}
	
	// 3. Infeksi
	reflex infection when: (current_place != buildings_per_activity["train_station","cemetery"] and live=1) {//mekanisme di RS harus beda
		/*
		 * Fungsi Infeksi :
		 * 1. Syaratnya berada didalam ruangan selain stasiun dan kuburan
		 * 2. Sedang karantina di rumah atau tidak karantina
		 * 3. Hidup
		 * 
		 * Alur:
		 * 1. Hitung jumlah orang didalam ruangan
		 * 2. Hitung jumlah yang terinfeksi
		 * 3. Hitung yang karantina (Jika dirumah)
		 * 4. Hitung faktor masker
		 * 5. Hitung probabilitas
		 * 6. Ambil kemungkinan, jika masih negatif maka ada kemungkinan positif
		 * 7. Covid status dari none menjadi terpapar (exposed)
		 * 8. Infection period dimulai
		 */
		
		list<Individual> people_inside <- current_place.Individuals_inside;
		int num_people <- length(people_inside - self);
		int num_infected <- length(people_inside where (each.covid_stat = "infected"));
		int num_quarantined <- length(people_inside where (each.s_quarantine_place = "home" and each.covid_stat = "infected"));
		float mask_factor <- 1 - mask_effectiveness*mask_usage_proportion;
		float proba <- 0.0;
		
		if (covid_stat = "none"){
			if (num_people > 0){
				float infection_proportion <- (num_infected+proportion_quarantined_transmission*num_quarantined)/num_people;
				list<int> l <- match_age(susceptibility.keys);
				proba <- get_proba(susceptibility[l],"gauss");
				proba <- proba * infection_proportion * mask_factor;
			}
		if (flip(proba)) {
			covid_stat <- "exposed";
			infection_period <- 0;
			}
		}
	}
	
	// 4. Update status infeksi biar timbul gejala
	reflex update_infection when: (covid_stat in ["exposed","infected"] and live = 1) {
		/*
		 * Syarat :
		 * 1. Covid status adalah terpapar dan positif
		 * 
		 * Alur :
		 * 1. Jika periode infeksi masih 0, maka dia mengambil distribusi untuk periode inkubasi
		 * 2. Jika mencapai periode inkubasi H-1 maka Covid status menjadi positif
		 * 3. Jika mencapai periode inkubasi maka akan di inisiasi infeksi untuk memunculkan symptomps, periode sakit dan periode sehat
		 * 4. Jika mencapai periode sakit maka symptomps akan berubah menjadi keparahan
		 * 5. Jika mencapai periode sehat, maka orang diharuskan untuk test
		 */
		if (infection_period = 0) {
			// Menentukan kapan hari gejala timbul
			list<int> l <- match_age(incubation_distribution.keys);
			incubation_period <- (24*incubation_distribution[l]);
			infection_period <- infection_period + 1;
		} else {
			infection_period <- infection_period + 1;
			
			// Merubah status sebenarnya menjadi terinfeksi
			if (infection_period = incubation_period-24){
				covid_stat <- "infected";
				
			// Mengambil periode sakit dan sehat serta memunculkan gejala
			} else if (infection_period = incubation_period) {
				
				do init_infection;//Ada tes obedience
				// Jika gejala moderate dia ga harus rapid dulu, langsung aja PCR
				if (symptomps in ["moderate"] and flip(obedience)){
					must_PCR_test <- true;
				// Jika gejala mild maka dia harus rapid terlebih dahulu
				} else if (symptomps in ["mild"] and flip(obedience)){
					must_rapid_test <- true;
				}
				
			// Merubah gejala menjadi keparahan, meningkat	
			} else if (infection_period = illness_period) {
				if (symptomps = "asymptom"){
					if flip(0.5) {
						severity <- "asymptom";
					}
					else if flip(0.4){
						severity <- "mild";
					}
					else {
						severity <- "moderate";
					}
				} else if (symptomps = "mild") {
					if flip(0.4) {
						severity <- "mild";
					}
					else if flip(0.4){
						severity <- "moderate";
					}
					else if flip(0.15) {
						severity <- "severe";
					}
					else {
						severity <- "critical";
					}
				} else if (symptomps = "moderate") {
					if flip(0.3) {
						severity <- "moderate";
					}
					else if flip(0.4){
						severity <- "severe";
					}
					else {
						severity <- "critical";
					}
				}
				
				
			// Merubah atribut klinis menjadi inisiasi awal
			} else if (infection_period = death_recovered_period) {
					//must_PCR_test <- true;
					covid_stat <- "none";
					infection_period <- 0;
					death_proba <- 0.02;
					severity <- "none";
					symptomps <- "none";
					//stat_covid <- "recovered";
					quarantine_period <- 0;
				//Else nya ya berarti pilihannya akan mati deh atau tambah
			}
		}
	}
	
	// 5. Reflex Quarantine
	reflex update_quarantine when: (current_hour = 1 and quarantine_status = true and live = 1) {
		if (stat_covid in ["suspect", "probable"]) {
			if (quarantine_period = 13){
				quarantine_status <- false;
				if ((symptomps != "none" or symptomps!="asymptom")and stat_covid = "suspect"){
					must_rapid_test <- true;
				}
				quarantine_period <- 0;
				stat_covid <- "discarded";
			}
			else {
				quarantine_period <- quarantine_period + 1;
			}
		}
		if (stat_covid = "confirmed"){ //if stat_covid = confirmed
			if (severity = "asymptom") {
				if (quarantine_period = 9) {
					stat_covid <- "recovered";
					quarantine_status <- false;
					quarantine_period <- 0;
				}
				else {
					quarantine_period <- quarantine_period + 1;
				}
			}
			else if (severity in ["mild", "moderate"]) {
				if (quarantine_period = 12) {
					stat_covid <- "recovered";
					quarantine_status <- false;
					quarantine_period <- 0;
					if (severity = "moderate" and s_quarantine_place = "hospital"){
						quarantine_place.patient_occupancy <- quarantine_place.patient_occupancy - 1;
					}
				}
				else {
					quarantine_period <- quarantine_period + 1;
				}
			}
			else { // severity = severe, critical
				if (quarantine_period = 10) {
					must_PCR_test <- true;
					quarantine_period <- quarantine_period + 1;
				}
				else if (quarantine_period >= 12) {
					if (pcr_result = 1 or pcr_result=4) {
						PCR_dayafter_count <- PCR_dayafter_count + 1;
					}
					else{
						stat_covid <- "recovered";
						quarantine_status <- false;
						quarantine_period <- 0;
						do delete_qplace;
						must_go_home <- true;
					}
					if (PCR_dayafter_count = 6) {
						must_PCR_test <- true;
						PCR_dayafter_count <- -2;
					}
					quarantine_period <- quarantine_period + 1;
				}
				else {
					quarantine_period <- quarantine_period + 1;
				}
			}
		}
	}
	
	
	// FUNGSI-FUNGSI LAIN
	
	list<int> match_age (list<list<int>> the_list) {
		/*
		 * Fungsi untuk mencocokkan atribut usia Individu dengan list<list<int>>.
		 */
		loop l over: the_list {
			if (age >= min(l) and age <= max(l)) {
				return l;
			}
		}
	}
	
	
	float get_proba(list<float> proba, string method) {
		/*
		 * Fungsi untuk memudahkan memanggil fungsi built-in
		 * untuk menentukan probabilitas dari distribusi.
		 */
		
		switch method {
			match "lognormal" {
				return lognormal_rnd(proba[0],proba[1]);
			}
			match "gauss" {
				return gauss_rnd(proba[0],proba[1]);
			}
			match "gamma" {
				return gamma_rnd(proba[0],proba[1]);
			}
		}
	}
	
	/*aspect circle {
		if (stat_covid = suspect) {
			draw circle(8) color: #white;
		} else if (stat_covid = probable) {
			draw circle(8) color: #orange;
		} else if (stat_covid = confirmed) {
			draw circle(8) color: #red;
		} else if (stat_covid = discarded) {
			draw circle(8) color: #blue;
		} else if (stat_covid = death) {
			draw circle(8) color: #black;
		} else if (stat_covid = recovered) {
			draw circle(8) color: #green;
		} else if (stat_covid = normal) {
			draw circle(8) color: #yellow;
		} else if (covid_stat = true) {
			draw circle(8) color: #purple;
		}
		highlight self color: #yellow;
	} //Untuk menentukan warna dari agent jika berubah status*/
	
	aspect circle {
		if (covid_stat = "infected") {
			draw circle(8) color: #red;
		} else if (covid_stat = "none") {
			draw circle(8) color: #green;
		} else if (covid_stat = "exposed") {
			draw circle(8) color: #blue;
		}
		highlight self color: #yellow;
	}
		
}

species Building {
	int patient_capacity;
	int icu_capacity;
	int patient_occupancy;
	int icu_occupancy;
	int icu_venti_capacity;
	int icu_venti_occupancy;
	int ch <- 0 update: current_hour;
	string type;
	list<Individual> Individuals_inside;
	list<Individual> residents;
	aspect geom {
		draw shape color: #lightcoral;
		highlight self color: #yellow;
	}
}

species Boundary {
	aspect geom {
		draw shape color: #turquoise;
	}
}

species Roads {
	aspect geom {
		draw shape color: #orange;
	}
}