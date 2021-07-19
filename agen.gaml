/**
* Name: tugasAkhir
* Based on the internal empty template. 
* Author: Fadhil
* Tags: 
*/


model tugasAkhir

import "init.gaml"
import "fungsi.gaml"
import "parameter.gaml"

/* Insert your model definition here */

species Individual {
	//------------------------//
	//-- Atribut individual --//
	//------------------------//
	
	// Atribut umum
	bool live <- true; //Status kehidupan agen
	int age; //Umur
	int sex; //Jenis kelamin, 0 male 1 female
	float proba_travel <- 0.01; //Kemungkinan orang melakukan perjalanan
	string stat_traveler <- none; //Status pelaku perjalanan, dibagi 4 yaitu none, commuter, leave and come
	int traveler_days;
	string job; //Jenis pekerjaan
	Building current_place; //Tempat saat ini
	Building home; //Rumah agen
	int max_travel_days <- rnd(7,21);
	
	// Atribut Agenda
	bool is_employed;
	string major_agenda_type;
	Building major_agenda_place;
	list<map<int, Building>> agenda_week;
	map<int,list<int>> major_agenda_hours;
	
	// Atribut Klinis
	int comorbid; //Jenis komorbid
	string stat_covid; //Status Covid
	string severity; //Keparahan Covid, muncul setelah fix Covid
	bool covid_stat; //Untuk melihat secara pasti seseorang Covid atau bukan
	bool quarantine_status <- false;
	int infection_period;
	int incubation_period; //Masa inkubasi menuju timbul gejala
	int quarantine_period <- 0; //Masa karantina
	int illness_period;
	int death_recovered_period;
	float death_proba <- 0; //Kemungkinan mati
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
	
	// Action Individual Umum
	
	// 1. Action masuk kedalam bangunan
	action enter_building(Building b){
		if (current_place != nil) {
			current_place.Individuals_inside >> self;
		}
		int x <- b.capacity - length(b.Individuals_inside where (major_agenda_place = b));
		if (x >= length(b.Individuals_inside)){ 
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
		
		if (not lockdown) {
			agenda_week[current_day_of_week][start] <- one_of(possible_minors);
			agenda_week[current_day_of_week][end] <- home;
		} else { // lockdown
			agenda_week[current_day_of_week][start] <- one_of(Building where ("marketplace","store" in possible_minor));
			agenda_week[current_day_of_week][end] <- home;
		}
	}
	
	
	// Action Individual Klinis
	
	// 1. Action PCR Test (Real)
	action real_PCR {
		Building h <- one_of(buildings_per_activity["hospital", "clinic"]);
		do enter_building(h);
		if (covid_stat) {
			bool test_result <- flip(sensitivity_pcr);
			if (test_result) {//real positive
				stat_covid <- confirmed;
				PCR_negative_count <- 0;
				pcr_result <- 1;
			}
			else { //si yang sebenarnya positif tp hasil tesnya negatif
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
				stat_covid <- confirmed;
				PCR_negative_count <- 0;
				pcr_result <- 1;
				
			}
		}
	}
	
	// 2. Contact Trace (Belum kelar)
	action contact_trace {
		
		list<Individual> contacts <- self.home.residents - self; //Contact trace untuk penghuni rumah
			
		contacts <- contacts + meet_today;
		
		// Menentukan jumlah kontak yang gagal di-trace, berdasarkan tracing effectivity.
		int num_contacts_untraced <- round((1-contact_tracing_effectiveness)*length(contacts));
		loop times: num_contacts_untraced {
			contacts >> one_of(contacts);
		}
		
		//Mengubah status menjadi harus karantina, dan membuat mereka harus test
		if (contacts != []) {
			ask contacts {
				if (quarantine_status = false) {
					quarantine_status <- flip(obedience*quarantine_obedience);
				}
				must_rapid_test <- true;
			}
		}
	}
	
	// 3. Initialisasi parameter infeksi
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
				symptomps <- moderate;
			} else {
				symptomps <- mild;
			}
		} else {
			symptomps <- asymptomic;
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
	
	// 4. Inisialisasi severity
	action init_severity{
		//Cek apakah dia asimptomp atau tidak
		list<int> l <- match_age(asymptomic_distribution.keys);
		float proba_asymptomic <- asymptomic_distribution[l];
		bool is_asymptomic <- flip(proba_asymptomic);
		
		//Cek apakah dia symptomic moderate
		l <- match_age(hospitalization_distribution.keys);
		float proba_moderate <- hospitalization_distribution[l];
		bool is_moderate <- flip(proba_moderate/(1-proba_asymptomic));
		
		//Cek apakah dia symptomic severe
		l <- match_age(ICU_distribution.keys);
		float proba_severe <- ICU_distribution[l];
		bool is_severe <- flip(proba_severe/proba_moderate);
		
		//Cek apakah dia akan menuju kematian
		l <- match_age(fatality_distribution.keys);
		float proba_fatal <- fatality_distribution[l];
		bool is_fatal <- flip(proba_fatal/proba_severe);
		
		//Cek apakah dia akan mati secara tiba2 or dadakan gitu
		l <- match_age(death_distribution.keys);
		float proba_death <- death_distribution[l];
		
		// Menentukan tingkat keparahan: asimptomatik, ringan, sedang, tinggi,
		// atau sangat tinggi, berdasarkan probabilitas simptomatik,
		// probabilitas masuk rumah sakit, probabilitas masuk ICU, serta
		// probabilitas kematian.
		if (is_asymptomic) {
			if (is_moderate) {
				if (is_severe) {
					if (is_fatal) {
						severity <- deadly;
						death_proba <- death_proba + proba_death*0.9;
					} else {
						severity <- severe;
						death_proba <- death_proba + proba_death*0.8;
					}
				} else {
					severity <- moderate;
					death_proba <- death_proba + proba_death*0.6;
				}
			} else {
				severity <- mild;
				death_proba <- death_proba + proba_death*0.4;
			}
		} else {
			severity <- asymptomic;
			death_proba <- death_proba + proba_death*0.2;
		}
	}
	
	// Reflex Individual Umum
	
	// 1. Reflex Bepergian atau Menjadi Traveler
	reflex the_traveler when : (current_hour = 20 and (flip(proba_travel) or stat_traveler = leave) and not lockdown and live = 1){ //Jadi syarat orang traveler tu jam 8 malam sama proba
		if (traveler_days = 0) {
			Building s <- one_of(buildings_per_activity["station"]);
			do enter_building(s);
			stat_traveler <- leave;
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
			
			stat_traveler <- none;
			traveler_days <- 0;
			stat_covid <- suspect;
			
			do enter_building(home); //Kalau udah ya dipulangkan
			}
		}
	
	// 2. Reflex Kematian	
	reflex death when : (current_hour = 23 and live = 1){
		Building c <- one_of(buildings_per_activity["cemetary"]);
		if (stat_covid in [normal,recovered,discarded]){
			if (flip(death_proba)){
				live <- 0;
				do enter_building(c);
			}
		}
		else if (stat_covid = confirmed){
			if (flip(death_proba)){
				live <- 0;
				stat_covid <- death;
				do enter_building(c);
			}
		}
		else {
			if (flip(death_proba)){
				live <- 0;
				stat_covid <- probable;
				do enter_building(c);
			}
		}
	}
	
	// 3. Reflex Menjalankan Agenda
	reflex execute_agenda when: (quarantine_status = false and stat_traveler != leave and live = 1) {
	//Kalau status karantina dan status bepergian tidak aktif	 
		map<int, Building> agenda_day <- agenda_week[current_day_of_week];
		if (agenda_day[current_hour] != nil) {
			do enter_building(agenda_day[current_hour]);
			if (stat_traveler = "come"){ //Jika dia traveler maka akan bertambah hari traveler nya
				traveler_days <- traveler_days - 1;
			}
			if (agenda_day[current_hour] = major_agenda_place){
				
			}
			if (not (major_agenda_type in [none])) {
				meet_yesterday <- meet_today;
				meet_today <- self.major_agenda_place.residents - self;
			}
		}
	}
	
	// 4. Reflex Add Minor Agenda
	reflex minor_agenda when: ((current_hour = 0) and (quarantine_status = false) and age >= min_student_age and age <= max_working_age and live = 1) {
		
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
	
	// 5. Reflex Hapus Minor Agenda
	reflex remove_minor_agenda when: current_hour = 23 and live = 1 {

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
	
	// 7. Reflex Update Quarantine (Belum, menunggu dari Azka)
	reflex update_quarantine when: (current_hour = 1 and quarantine_status = true) and live {
		if (stat_covid in ["suspect", "probable"]) {
			if (quarantine_period = 13){
				quarantine_status <- false;
			}
			else {
				quarantine_period <- quarantine_period + 1;
			}
		}
		else{ //if stat_covid = confirmed
			if (quarantine_period = 6){
				must_PCR_test <- true;
			}
			else {
				quarantine_period <- quarantine_period + 1;
			}
		}
	}
	
	// Reflex Individual Klinis
	
	// 1. Reflex Test Rapid
	reflex rapid_test when: (current_hour = 6 and (symptomps = mild or must_rapid_test)) and live = 1 {
		Building h <- one_of(buildings_per_activity["hospital", "clinic"]);
		do enter_building(h);
		if (covid_stat) {
			bool test_result <- flip(sensitivity_rapid); //Harus test rapid (Penting)
			if (test_result) {//true positive
				stat_covid <- confirmed;
				quarantine_status <- true;
				rapid_result <- 1;
				do contact_trace;
			}
			else { //si yang sebenarnya positif tp hasil tesnya negatif
				if (symptomps = mild or asymptomic) {
					stat_covid <- suspect;
					quarantine_status <- flip(obedience*quarantine_obedience);
				}
				else {
					stat_covid <- probable;
					quarantine_status <- true;
					must_PCR_test <- true;
				}
				rapid_result <- 2;
			}
		}
		else {
			bool test_result <- flip(specificity_rapid);
			if (test_result) {
				if (symptomps = mild or asymptomic) {
					stat_covid <- suspect;
					quarantine_status <- flip(obedience*quarantine_obedience);
				}
				else {
					stat_covid <- probable;
					quarantine_status <- true;
					must_PCR_test <- true;
				}
				rapid_result <- 2;
			}
			else { //si yang sebenarnya negatif tp hasil tesnya positif
				stat_covid <- confirmed;
				quarantine_status <- true;
				rapid_result <- 1;
				do contact_trace;
			}
		}
		
	}
	
	// 2. Reflex PCR Test (Inisiasi)
	reflex pcr_test when: (current_hour = 6 and (must_PCR_test or symptomps = [moderate,severe])) and live {
		if (PCR_waiting_day != 2) {
			have_PCR <- true;
			quarantine_status <- true;
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
	
	// 3. Infeksi
	reflex infection when: (quarantine_status in [possible_livings, false]) and live { //Syarat nya adalah jika serumah dengan orang yang positif atau ga karantina
		
		list<Individual> people_inside <- current_place.Individuals_inside where (not dead(each));
		int num_people <- length(people_inside - self);
		int num_infected <- length(people_inside where (each.quarantine_status = false and each.covid_stat = true));
		int num_quarantined <- length(people_inside where (each.quarantine_status = true and each.covid_stat = true));
		float mask_factor <- 1 - mask_effectiveness*mask_usage_proportion;
		float proba <- 0.0;
		
		if (covid_stat = false){
			if (num_people > 0){
				float infection_proportion <- (num_infected+proportion_quarantined_transmission*num_quarantined)/num_people;
				list<int> l <- match_age(susceptibility.keys);
				proba <- get_proba(susceptibility[l],"gauss");
				proba <- proba * infection_proportion * mask_factor * (1-infection_reduction_factor);
			}
		if (flip(proba)) {
			covid_stat <- true;
			incubation_period <- 0;
			}
		}
	}
	
	// 4. Update status infeksi biar timbul gejala
	reflex update_infection when: (covid_stat) and live = 1 {
		if (infection_period = 0) {
			infection_period <- infection_period + 1;
		} else {
			
			infection_period <- infection_period + 1;
			
			if (infection_period = incubation_period) {
				
				do init_infection;
				// Jika gejala moderate ama severe dia ga harus rapid dulu, langsung aja PCR
				if (symptomps = [moderate,severe] and not quarantine_status){
					must_PCR_test <- true;
				}
				
			} else if (infection_period = illness_period) {
				// Skenario 1 (Severity bisa random dan bisa lebih rendah dari symptomps)
				// Jika sudah di titik penyakit terdiagnosa, ini diambil sekian hari dari incubation period antara 1-3 hari
				do init_severity;
				
			/*
			 * Skenario 2 (Severity antara tetap atau naik dari symptomp
			 * 
			 * if (symptomps = asymptomic){
			 * 		severity <- rnd[asymptomic,mild,moderate,severe,deadly];
			 * } else if (symptomps = mild) {
			 * 		severity <- rnd[mild,moderate,severe,deadly];
			 * } else if (symptomps = moderate) {
			 * 		severity <- rnd[moderate,severe,deadly];
			 * }
			 */
				
				// Recovery dan kematian
			} else if (infection_period = death_recovered_period) { //Masih error krna datanya blm ada di parameter
					must_PCR_test <- true;
					covid_stat <- false;
					infection_period <- 0;
					death_proba <- 0;
					severity <- none;
					symptomps <- none;
				//Else nya ya berarti pilihannya akan mati deh atau tambah
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
		if (stat_covid = suspect) {
			draw circle(8) color: #yellow;
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
			draw circle(8) color: #white;
		}
		highlight self color: #white;
	} //Untuk menentukan warna dari agent jika berubah status
	
		
}

species Building {
	int total_property;
	int capacity;
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
