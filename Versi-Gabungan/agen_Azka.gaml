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
	int traveler_days;
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
	int comorbid; //Jenis komorbid
	string stat_covid <- "normal"; //Status Covid
	string severity; //Keparahan Covid, muncul setelah fix Covid
	bool covid_stat; //Untuk melihat secara pasti seseorang Covid atau bukan
	bool quarantine_status <- false;
	int infection_period;
	int incubation_period; //Masa inkubasi menuju timbul gejala
	int quarantine_period <- 0; //Masa karantina
	int death_recovered_period;
	int illness_period;
	float death_proba <- 0.0; //Kemungkinan mati
	string symptomps; //Gejala awal sebelum pasti Covid
	bool must_rapid_test <- false; //Status wajib test jika kena contact trace
 	bool must_PCR_test <- false; //Status wajib test jika kena contact trace
 	int PCR_negative_count; //Hitungan berapa jumlah sudah test PCR
 	bool have_PCR; //Status apakah sudah PCR
 	int PCR_waiting_day; //Hari menunggu hasil PCR
	int rapid_result <- 0; //1 positif, 2 negatif
	int pcr_result <- 0;
	float obedience; //(Penting) Dipisah sebaiknya satu persatu. Ini bukannya udah ada di parameter.gaml?
	int type_of_death; // 0 normal, 1 confirmed, 2 probable
	list<Individual> meet_today; //Untuk melihat yang ditemui di hari ini
	list<Individual> meet_yesterday; //Untuk melihat yang ditemui di kemaren 
	Building quarantine_place;
	
	
	// Action Individual Umum
	
	// 1. Action masuk kedalam bangunan
	action enter_building(Building b){
		if (current_place != nil) {
			current_place.Individuals_inside >> self;
		}
		if (b.capacity >= length(b.Individuals_inside)){ 
		//Jika kapasitas masih dibawah atau sama dengan kapasitas ruangan maka masuk, kalau ga pulang
			current_place <- b;
		} else {
			current_place <- home;
		}
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
	action real_PCR { // MASIH BELUM BETUL
		//enter rumah sakit buat ambil hasil test
		do enter_building(test_place);
		
		if (covid_stat) {
			bool test_result <- flip(sensitivity_pcr);
			if (test_result) {// TRUE POSITIVE
				stat_covid <- "confirmed";
				PCR_negative_count <- 0;
				pcr_result <- 1;
			}
			else { //FALSE NEGATIVE
				PCR_negative_count <- PCR_negative_count + 1;
				pcr_result <- 2;
			}
		}
		else {
			bool test_result <- flip(specificity_pcr);
			if (test_result) { // real negative
				PCR_negative_count <- PCR_negative_count + 1;
				pcr_result <- 2;
			}
			else { //si yang sebenarnya negatif tp hasil tesnya positif
				stat_covid <- "confirmed";
				PCR_negative_count <- 0;
				pcr_result <- 1;
				
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
				}
				must_rapid_test <- true;
			}
		}
	}
	
	//3. Action Quarantine
	
	action init_quarantine{ 
		int temp<-1;
		quarantine_status <- true;
		
		if (severity in ["asymptom", "mild"]) { //Belum mempertimbangkan yang di pusat karantine (wisma haji)
			quarantine_place <- home;
		}
		else if (severity in ["moderate","severe"]){
			quarantine_place <- one_of(buildings_per_activity["hospital"]);
			loop while: (quarantine_place.patient_capacity = quarantine_place.patient_occupancy and temp <= total_hospital){
				quarantine_place <- one_of(buildings_per_activity["hospital"]); // selama kapasitas RS udah penuh, cari RS lain
				temp <- temp+1;
			}
			
			//Jika semua RS penuh, maka karantina di rumah
			if temp>total_hospital {
				quarantine_place <- home;
			}
			else {
				quarantine_place.patient_occupancy <- quarantine_place.patient_occupancy + 1;
			}
			do enter_building(quarantine_place);
		}
		else { // severity = critical
			quarantine_place <- one_of(buildings_per_activity["hospital"]);
			loop while: (quarantine_place.icu_capacity = quarantine_place.icu_occupancy and temp <= total_hospital){
				quarantine_place <- one_of(buildings_per_activity["hospital"]); // selama kapasitas RS udah penuh, cari RS lain
				temp <- temp+1;
			}
			
			//Jika semua ICU penuh, maka isolasi di kamar biasa di RS
			if temp > total_hospital {
				temp<-1;
				loop while: (quarantine_place.patient_capacity = quarantine_place.patient_occupancy and temp <= total_hospital){
					quarantine_place <- one_of(buildings_per_activity["hospital"]); // selama kapasitas RS udah penuh, cari RS lain
					temp <- temp+1;
				}
				//Jika semua kamar biasa penuh, maka isolasi di rumah
				if temp > total_hospital {
					quarantine_place <- home;
				}
				else {
					quarantine_place.patient_occupancy <- quarantine_place.patient_occupancy + 1;
				}
			}
			else {
				quarantine_place.icu_occupancy <- quarantine_place.icu_occupancy + 1;
			}
			do enter_building(quarantine_place);
		}
	}
	
	// 4. Initialisasi parameter infeksi Symptomp
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
			symptomps <- "asymptomic";
		}
		
		// Menentukan kapan hari gejala timbul
		l <- match_age(incubation_distribution.keys);
		incubation_period <- int(24*incubation_distribution[l]);
		
		// Menentukan penyakit tersebut berubah menjadi severity
		illness_period <- int(24*get_proba(days_diagnose, "normal")) + incubation_period;
		
		// Menentukan kapan hari sembuh
		l <- match_age(days_symptom_until_recovered.keys);
		death_recovered_period <- int(24*get_proba(days_symptom_until_recovered[l], "normal")) + illness_period;
		
	}
	
	// Reflex Individual Umum
	
	// 1. Reflex Bepergian atau Menjadi Traveler
	reflex the_traveler when : (current_hour = 20 and (flip(proba_travel) or stat_traveler="leave") and live = 1){ 
	//Jadi syarat orang traveler tu jam 8 malam sama proba
		if (traveler_days = 0) {
			Building s <- one_of(buildings_per_activity["station"]);
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
			
			if (covid_stat = false){
				list<int> l <- match_age(susceptibility.keys);
				proba <- get_proba(susceptibility[l],"gauss");
				proba <- proba * mask_factor * (1-infection_reduction_factor);
			}
			
			if (flip(proba)) {
				covid_stat <- true;
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
	reflex death when : (current_hour = 23 and live = 1){
		
		if (stat_covid in ["normal","recovered","discarded"]){
			if (flip(death_proba)){
				live <- 0;
			}
		}
		else if (stat_covid = "confirmed"){
			float covid_confirmed_death_proba <- 0.0; //Ntar disesuaikan
			float proba_death <- death_proba*covid_confirmed_death_proba;
			if (flip(proba_death)){
				live <- 0;
			}
		}
		else if (stat_covid = "probable"){
			float covid_probable_death_proba <- 0.0; //Ntar disesuaikan
			float proba_death <- death_proba*covid_probable_death_proba;
			if (flip(proba_death)){
				live <- 0;
			}
		}
		else {
			if (stat_covid = "suspect"){
				float covid_suspect_death_proba <- 0.0; //Ntar disesuaikan
				float proba_death <- death_proba*covid_suspect_death_proba;
				if (flip(proba_death)){
					live <- 0;
				}
			}
		}
		
	}
	
	// 3. Reflex Periksa Kematian Individu
	reflex death_check when : (current_hour = 22 and live = 0){
		Building c <- one_of(buildings_per_activity["cemetary"]);
		if (stat_covid in ["normal","recovered","discarded"]){
			type_of_death <- 0;
		}
		else if (stat_covid = "confirmed"){
			type_of_death <- 1;
			stat_covid <- "death";			do enter_building(c);
		}
		else {
			type_of_death <- 2;
			stat_covid <- "probable";
		}
		do enter_building(c);
	}
	
	// 4. Reflex Menjalankan Agenda
	reflex execute_agenda when: (quarantine_status = false and stat_traveler != "leave" and live = 1) {
	//Kalau status karantina dan status bepergian tidak aktif	 
		map<int, Building> agenda_day <- agenda_week[current_day_of_week];
		if (agenda_day[current_hour] != nil) {
			do enter_building(agenda_day[current_hour]);
			if (not (major_agenda_type in ["none"])) {
				meet_yesterday <- meet_today;
				meet_today <- self.major_agenda_place.residents - self;
			}
		}
	}
	
	// 5. Reflex Quarantine
	reflex update_quarantine when: (current_hour = 1 and quarantine_status = true) {
		if (stat_covid in ["suspect", "probable"]) {
			if (quarantine_period = 13){
				quarantine_status <- false;
				if (symptomps != "none" and stat_covid = "suspect"){
					must_rapid_test <- true;
				}
				quarantine_period <- 0;
			}
			else {
				quarantine_period <- quarantine_period + 1;
			}
		}
		else{ //if stat_covid = confirmed
			if (quarantine_period = 6){
				must_PCR_test <- true;
				quarantine_period <- 0;
			}
			else {
				quarantine_period <- quarantine_period + 1;
			}
		}
	}
	
	// Reflex Individual Klinis
	
	// 1. Reflex Test Rapid
	reflex rapid_test when: (must_rapid_test and current_hour = 6) {
		Building h <- one_of(buildings_per_activity["hospital", "clinic"]);
		do enter_building(h);
		
		if (covid_stat) {
			bool test_result <- flip(sensitivity_rapid); //Harus test rapid (Penting)
			if (test_result) {//true positive
				if (symptomps != "asymptom") {
					stat_covid <- "confirmed";
					do init_quarantine;
				}
				else {
					//do contact_tracing_ps;
					//if (count != 0){
						//stat_covid <- "confirmed";
						//do init_quarantine;
					//	}
					//else {
						//must_PCR_test<-true;
						//quarantine_status <- true;
						//quarantine_place <- home;
					//}
				}
				rapid_result <- 1;
			}
			else { //si yang sebenarnya positif tp hasil tesnya negatif
				if (symptomps in ["asymptom", "mild"]) {
					stat_covid <- "suspect";
					quarantine_status <- flip(obedience*quarantine_obedience);
					if (quarantine_status = true) {
						quarantine_place <- home;
					}
				}
				else {
					stat_covid <- "probable";
					quarantine_status <- true;
					quarantine_place <- home;
					must_PCR_test <- true;
				}
				rapid_result <- 2;
			}
		}
		else {
			bool test_result <- flip(specificity_rapid);
			if (test_result) {
				if (symptomps in ["asymptom", "mild"]) {
					stat_covid <- "suspect";
					quarantine_status <- flip(obedience*quarantine_obedience);
					if (quarantine_status = true) {
						quarantine_place <- home;
					}
				}
				else {
					stat_covid <- "probable";
					quarantine_status <- true;
					quarantine_place <- home;
					must_PCR_test <- true;
				}
				rapid_result <- 3;
			}
			else { //si yang sebenarnya negatif tp hasil tesnya positif
				if (symptomps != "asymptom") {
					stat_covid <- "confirmed";
					do init_quarantine;
				}
				else {
					//do contact_tracing_ps;
					//if (count != 0){
						//stat_covid <- "confirmed";
						//do init_quarantine;
					//	}
					//else {
						//must_PCR_test<-true;
						//quarantine_status <- true;
						//quarantine_place <- home;
					//}
				}
				rapid_result <- 4;
			}
		}
	
	} 

	
	// 2. Reflex PCR Test (Inisiasi)
	reflex pcr_test when: (must_PCR_test and current_hour = 6) {
		if (PCR_waiting_day = 0) {
			have_PCR <- true;
			quarantine_status <- true;
			PCR_waiting_day <- PCR_waiting_day + 1;
			
			//enter building rs atau klinik
			Building h <- one_of(buildings_per_activity["hospital", "clinic"]);
			do enter_building(h);
			test_place <- h;
			}
		else if (PCR_waiting_day =1) {
			PCR_waiting_day <- PCR_waiting_day + 1;
			}
		else {
			do real_PCR;
			PCR_waiting_day <- 0;
			must_PCR_test <- false;
			quarantine_period <- 2;
			if (PCR_negative_count = 2){
				quarantine_status <- false;
				stat_covid <- "recovered";
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
	
	aspect circle {
		if (stat_covid = "suspect") {
			draw circle(8) color: #yellow;
		} else if (stat_covid = "probable") {
			draw circle(8) color: #orange;
		} else if (stat_covid = "confirmed") {
			draw circle(8) color: #red;
		} else if (stat_covid = "discarded") {
			draw circle(8) color: #blue;
		} else if (stat_covid = "death") {
			draw circle(8) color: #black;
		} else if (stat_covid = "recovered") {
			draw circle(8) color: #green;
		} else if (stat_covid = "normal") {
			draw circle(8) color: #white;
		}
		highlight self color: #white;
	} //Untuk menentukan warna dari agent jika berubah status
	
		
}

species Building {
	int total_property;
	int capacity;
	int patient_capacity;
	int icu_capacity;
	int patient_occupancy;
	int icu_occupancy;
	int icu_venti_total;
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