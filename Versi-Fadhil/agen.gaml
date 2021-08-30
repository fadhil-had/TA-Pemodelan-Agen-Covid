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
	bool live; //Status kehidupan agen
	int age; //Umur
	int sex; //Jenis kelamin, 0 male 1 female
	Building current_place; //Tempat saat ini
	Building home; //Rumah agen
	
	// Atribut Agenda
	bool is_employed;
	string major_agenda_type;
	Building major_agenda_place;
	list<map<int, Building>> agenda_week;
	map<int,list<int>> major_agenda_hours;
	
	// Atribut Klinis
	string stat_covid <- normal; //Status Covid
	string covid_stat <- none; //Untuk melihat secara pasti seseorang Covid atau bukan
	string symptomps <- none; //Gejala awal sebelum pasti Covid
	string severity <- none; //Keparahan Covid, muncul setelah fix Covid
	float death_proba <- proba_death;
	string quarantine_place <- none;
	int infection_period <- 0; //Masa inkubasi seseorang
	int incubation_period <- 0; //Masa inkubasi menuju timbul gejala
	int quarantine_period <- 0; //Masa karantina
	int illness_period <- 0; //Masa sakit
	int death_recovered_period <- 0; //Masa menuju sehat
	bool must_rapid_test <- false; //Status wajib test jika kena contact trace
 	bool must_PCR_test <- false; //Status wajib test jika kena contact trace
	list<Individual> meet_today; //Untuk melihat yang ditemui di hari ini
	list<Individual> meet_yesterday; //Untuk melihat yang ditemui di kemaren
	
 	// Atribut Sosial Ekonomis
	string stat_traveler <- none; //Status pelaku perjalanan, dibagi 4 yaitu none, commuter, leave and come
	int traveler_days <- 0;
	int max_travel_days <- rnd(3,10);
 	float salary;
 	float covid_salary;
 	float property; //Total kekayaan.
 	bool poor;
	
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
		
		if (not lockdown or not psbb) {
			agenda_week[current_day_of_week][start] <- one_of(Building where (each.type in possible_minors));
			agenda_week[current_day_of_week][end] <- home;
		} else { // lockdown
			agenda_week[current_day_of_week][start] <- one_of(Building where (each.type in ["marketplace","store","supermarket"]));
			agenda_week[current_day_of_week][end] <- home;
		}
	}
	
	
	// Action Individual Klinis
	
	// 1. Contact Trace (Belum kelar)
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
				if (quarantine_place = none) {
					if (flip(obedience*quarantine_obedience)){
						quarantine_place <- house;
					} else {
						quarantine_place <- none;
					}
				}
				must_rapid_test <- true;
			}
		}
	}
	
	// 2. Initialisasi parameter infeksi
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
		
		// Menentukan penyakit tersebut berubah menjadi severity
		l <- match_age(days_diagnose.keys);
		illness_period <- int(24*get_proba(days_diagnose[l],"gauss")) + incubation_period;
		
		// Menentukan kapan hari sembuh
		l <- match_age(days_symptom_until_recovered.keys);
		death_recovered_period <- int(24*get_proba(days_symptom_until_recovered[l],"gauss")) + illness_period;
		
	}
	
	
	// Reflex Individual Umum
	
	// 1. Reflex Bepergian atau Menjadi Traveler
	reflex the_traveler when : (current_hour = 20 and ((flip(proba_travel) and traveler_days = 0) or stat_traveler = leave) and not lockdown and quarantine_place = none and live = true){ //Jadi syarat orang traveler tu jam 8 malam sama proba
		if (traveler_days = 0) {
			Building s <- one_of(buildings_per_activity[station]);
			do enter_building(s);
			stat_traveler <- leave;
			traveler_days <- traveler_days + 1;
		}
		else if (traveler_days != max_travel_days) { //Kalau dia belum 7-21 hari, dia di stasiun dan akan stay
			traveler_days <- traveler_days + 1;
			}
		else {
			do enter_building(home); //Pulang
			
			// Ternyata positif
			float mask_factor <- 1 - mask_effectiveness*mask_usage_proportion;
			float proba <- 0.0;
			
			if (covid_stat = none){
				list<int> l <- match_age(susceptibility.keys);
				proba <- get_proba(susceptibility[l],"gauss");
				proba <- proba * mask_factor * proba_travel_infected;
			}
			
			if (flip(proba)) {
				covid_stat <- exposed;
				incubation_period <- 0;
			}
			
			stat_traveler <- none;
			traveler_days <- 0;
			stat_covid <- suspect;
			bool quarantine <- flip(obedience*quarantine_obedience);
			if (quarantine){
				quarantine_place <- house;
			} else if (not(quarantine)) {
				quarantine_place <- none;
			}
			
		}
	}
	
	// 2. Reflex Kematian	
	reflex death when : (current_hour = 21 and live = true){
		Building c <- one_of(buildings_per_activity["cemetery"]);
		if (flip(death_proba)){
			if (stat_covid in [normal,recovered,discarded]){
				live <- false;
				do enter_building(c);
			} else if (stat_covid = confirmed){
				live <- false;
				stat_covid <- death;
				do enter_building(c);
			} /*else {
				live <- false;
				stat_covid <- probable;
				do enter_building(c);
			}*/
		} else {
			live <- true;
		}
	}
	
	// 3. Reflex Menjalankan Agenda
	reflex execute_agenda when: (quarantine_place = none and stat_traveler != leave and live = true) {
	//Kalau status karantina dan status bepergian tidak aktif
		map<int, Building> agenda_day <- agenda_week[current_day_of_week];
		if (agenda_day[current_hour] != nil) {
			do enter_building(agenda_day[current_hour]);
			if (agenda_day[current_hour].type = any(possible_minors)){
				if (age > 17 and age <= max_working_age){
					property <- property - 5;
				}
			}
			if (agenda_day[current_hour].type in [major_agenda_place]) {
				meet_yesterday <- meet_today;
				meet_today <- self.major_agenda_place.residents - self;
			}
		}
	}
	
	// 4. Reflex Add Minor Agenda
	reflex minor_agenda when: ((current_hour = 0) and age >= min_student_age and age <= max_working_age and live = true) {
		
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
	reflex remove_minor_agenda when: current_hour = 23 and live = true {

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
	
	// 6. Reflex economical
	reflex economical when: age >= 19 and age <= max_working_age and current_day = 7 and current_hour = 18 and live = true {
		if (is_employed){
			if (not lockdown or not psbb or not new_normal){
				property <- property + salary; //Kekayaan ditambah dengan gaji
				self.home.total_property <- self.home.total_property + salary; //Harta 1 keluarga
			} else {
				property <- property + covid_salary; //Kekayaan ditambah dengan gaji
				self.home.total_property <- self.home.total_property + covid_salary; //Harta 1 keluarga
			}
		} else if (major_agenda_type = "school" and age >= 17) {
			property <- property + salary;
			self.home.total_property <- self.home.total_property - salary; //Biaya hidup ditanggung keluarga
		}
		
		float x <- rnd(0.5,2.0); //Biaya hidup orang2 sesuai dengan gaya masing2;
		if (poor){
			x <- rnd(0.1,1.0); //Kalau miskin orang2 berhemat
		}
	
		float out <- salary*x;
		if (out < 500.0){ //Jika biaya hidup nya dibawah setengah biaya hidup rata2 di Surabaya maka dibuat segitu
			out <- 500.0;
		}
		
		if (major_agenda_type = "school" and age >= 17){
			property <- property - (out); //Pengeluaran hanya kena ke harta pribadi, karena harta rumah dikurangi diawal
		} else {
			property <- property - (out); //Belanja disesuaikan dengan gaji
			self.home.total_property <- self.home.total_property - (out);
		}
		
		if (property > 550){
			poor <- false;
		} else {
			poor <- true;
		}
	}
	
	// Reflex Individual Klinis
	
	// 1. Reflex Test Rapid
	reflex rapid_test when: current_hour = 6 and (must_rapid_test and flip(proba_test)) and stat_traveler != leave and stat_covid != confirmed and live {
		Building h <- one_of(buildings_per_activity["hospital", "clinic"]);
		do enter_building(h);
		if (covid_stat in [infected]) {
			bool test_result <- flip(sensitivity_rapid*test_accuracy); //Harus test rapid (Penting)
			if (test_result) {//true positive
				stat_covid <- confirmed;
				do contact_trace;
				if (symptomps in none){
					symptomps <- asymptomic;
				}
				switch symptomps {
					match mild {
						quarantine_place <- hospital;
					}
					match moderate {
						quarantine_place <- hospital;
					}
					match asymptomic {
						do enter_building(home);
						quarantine_place <- house;
					}
					match none {
						do enter_building(home);
						quarantine_place <- house;
					}
				}
				quarantine_period <- 0;
			} else if (not(test_result)) { //si yang sebenarnya positif tp hasil tesnya negatif
				do enter_building(home);
				if (symptomps in [mild,asymptomic]){
					stat_covid <- probable;
					bool quarantine <- flip(obedience*quarantine_obedience);
					if (quarantine){
						quarantine_place <- house;
					} else if (not(quarantine)) {
						quarantine_place <- none;
					}
				}
				else if (symptomps in [moderate]) {
					stat_covid <- probable;
					must_PCR_test <- true;
					quarantine_place <- house;
				}
			}
		} else if (covid_stat in [none,exposed]) {
			bool test_results <- flip(specificity_rapid*test_accuracy);
			if (test_results) {
				do enter_building(home);
				quarantine_place <- none;
			} else if (not(test_results)){ //si yang sebenarnya negatif tp hasil tesnya positif
				stat_covid <- confirmed;
				do contact_trace;
				switch symptomps {
					match mild {
						quarantine_place <- hospital;
					}
					match moderate {
						quarantine_place <- hospital;
					}
					match asymptomic {
						do enter_building(home);
						quarantine_place <- house;
					}
					match none {
						do enter_building(home);
						quarantine_place <- house;
					}
				}
				quarantine_period <- 0;
			}
		}
		must_rapid_test <- false; // Harus diinisiasi ulang biar orang ga test rapid terus2an tiap hari
	}
	
	// 2. Reflex Test PCR
	reflex pcr_test when: current_hour = 6 and (must_PCR_test and flip(proba_test)) and stat_covid != confirmed and stat_traveler != leave and live {
		Building h <- one_of(buildings_per_activity["hospital", "clinic"]);
		do enter_building(h);
		if (covid_stat in [infected]) {
			bool test_result <- flip(sensitivity_pcr*test_accuracy); //Harus test rapid (Penting)
			if (test_result) {//true positive
				stat_covid <- confirmed;
				do contact_trace;
				if (symptomps in none){
					symptomps <- asymptomic; 
				}
				quarantine_period <- 0;
				switch symptomps {
					match mild {
						quarantine_place <- hospital;
					}
					match moderate {
						quarantine_place <- hospital;
					}
					match asymptomic {
						do enter_building(home);
						quarantine_place <- house;
					}
					match none {
						do enter_building(home);
						quarantine_place <- house;
					}
				}
			}
			else if (not(test_result)) { //si yang sebenarnya positif tp hasil tesnya negatif
				do enter_building(home);
				if (symptomps in [mild,asymptomic]){
					stat_covid <- suspect;
					bool quarantine <- flip(obedience*quarantine_obedience);
					if (quarantine){
						quarantine_place <- house;
					} else if (not(quarantine)) {
						quarantine_place <- none;
					}
				}
				else if (symptomps in [moderate]) {
					stat_covid <- probable;
					must_PCR_test <- true;
					quarantine_place <- hospital;
				}
			}
		} else if (covid_stat in [none,exposed]) {
			bool test_results <- flip(specificity_pcr*test_accuracy);
			if (test_results) {
				if (symptomps in [mild,asymptomic,none]) {
					do enter_building(home);
					stat_covid <- suspect;
					bool quarantine <- flip(obedience*quarantine_obedience);
					if (quarantine){
						quarantine_place <- house;
					} else if (not(quarantine)) {
						quarantine_place <- none;
					}
				}
				else if (symptomps in [moderate]) {
					stat_covid <- probable;
					quarantine_place <- hospital;
				}
			}
			else if (not(test_results)) { //si yang sebenarnya negatif tp hasil tesnya positif
				stat_covid <- confirmed;
				death_recovered_period <- 24 * 14;
				do contact_trace;
				switch symptomps {
					match mild {
						quarantine_place <- hospital;
					}
					match moderate {
						quarantine_place <- hospital;
					}
					match asymptomic {
						do enter_building(home);
						quarantine_place <- house;
					}
					match none {
						do enter_building(home);
						quarantine_place <- house;
					}
				}
				quarantine_period <- 0;
			}
		}
		must_PCR_test <- false;
	}
	
	// 3. Infeksi
	reflex infection when: (current_place != buildings_per_activity["train_station","cemetery"]) and (quarantine_place in [house,none]) and live {
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
		int num_infected <- length(people_inside where (each.quarantine_place = none and each.covid_stat = infected));
		int num_quarantined <- length(people_inside where (each.quarantine_place = none and each.covid_stat = infected));
		float mask_factor <- 1 - mask_effectiveness*mask_usage_proportion;
		float proba <- 0.0;
		
		if (covid_stat = none){
			if (num_people > 0){
				float infection_proportion <- (num_infected+proportion_quarantined_transmission*num_quarantined)/num_people;
				list<int> l <- match_age(susceptibility.keys);
				proba <- get_proba(susceptibility[l],"gauss");
				proba <- proba * infection_proportion * mask_factor;
			}
		if (flip(proba)) {
			covid_stat <- exposed;
			infection_period <- 0;
			}
		}
	}
	
	// 4. Update status infeksi biar timbul gejala
	reflex update_infection when: (covid_stat in [exposed,infected]) and live = true {
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
				covid_stat <- infected;
				
			// Mengambil periode sakit dan sehat serta memunculkan gejala
			} else if (infection_period = incubation_period) {
				
				do init_infection;
				// Jika gejala moderate dia ga harus rapid dulu, langsung aja PCR
				if (symptomps in [moderate]){
					must_PCR_test <- true;
				// Jika gejala mild maka dia harus rapid terlebih dahulu
				} else if (symptomps in [mild]){
					must_rapid_test <- true;
				}
				
			// Merubah gejala menjadi keparahan, meningkat	
			} else if (infection_period = illness_period) {
				if (symptomps = asymptomic){
					severity <- one_of(asymptomic,mild,moderate,severe,deadly);
				} else if (symptomps = mild) {
					severity <- one_of(mild,moderate,severe,deadly);
				} else if (symptomps = moderate) {
					severity <- one_of(moderate,severe,deadly);
				}
				
				bool quarantine <- flip(obedience*quarantine_obedience);
				switch severity {
					match asymptomic {
						if (quarantine){
							quarantine_place <- house;
						}
					}
					match mild {
						if (quarantine){
							do enter_building(one_of(buildings_per_activity["hospital","clinic"]));
							quarantine_place <- hospital;
						}
						death_proba <- 1.05*death_proba;
					}
					match moderate {
						if (quarantine){
							do enter_building(one_of(buildings_per_activity["hospital","clinic"]));
							quarantine_place <- hospital;
						}
						death_proba <- 1.05*death_proba;
					}
					match severe {
						do enter_building(one_of(buildings_per_activity["hospital","clinic"]));
						quarantine_place <- ICU;
						death_proba <- 1.5*death_proba;
					}
					match deadly {
						do enter_building(one_of(buildings_per_activity["hospital","clinic"]));
						quarantine_place <- ICU;
						death_proba <- 1.7*death_proba;
					}
				}
				
			// Merubah atribut klinis menjadi inisiasi awal
			} else if (infection_period = death_recovered_period) {
					//must_PCR_test <- true;
					covid_stat <- none;
					infection_period <- 0;
					death_proba <- proba_death;
					severity <- none;
					symptomps <- none;
					stat_covid <- recovered;
					quarantine_place <- none;
					quarantine_period <- 0;
				//Else nya ya berarti pilihannya akan mati deh atau tambah
			}
		}
	}
	
	// 7. Reflex Update Quarantine
	reflex update_quarantine when: (quarantine_place in [house,hospital,ICU]) and live {
		if (stat_covid in [suspect, probable]) {
			if (quarantine_period = 13*24){
				quarantine_place <- none;
				stat_covid <- discarded;
				quarantine_period <- 0;
			}
			else {
				quarantine_period <- quarantine_period + 1;
			}
		} else if (stat_covid in confirmed) { //if stat_covid = confirmed
			quarantine_period <- quarantine_period + 1;
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
			match "random" {
				return rnd(proba[0],proba[1]);
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
		if (covid_stat = infected) {
			draw circle(8) color: #red;
		} else if (covid_stat = none) {
			draw circle(8) color: #green;
		} else if (covid_stat = exposed) {
			draw circle(8) color: #blue;
		}
		highlight self color: #yellow;
	}
		
}

species Building {
	float total_property;
	int capacity;
	int ch <- 0 update: current_hour;
	string type;
	bool family_poor;
	list<Individual> Individuals_inside;
	list<Individual> residents;
	reflex economical_home when: (type in possible_livings and current_day = 7){
		if (total_property > 0){
			family_poor <- false;
		} else {
			family_poor <- true;
		}
	}
	aspect geom {
		draw shape color: #lightcoral;
		highlight self color: #yellow;
	}
}

species Boundary {
	aspect geom {
		draw shape color: #turquoise;
		/*if (lockdown){
			draw shape color: #black;
		} else if (psbb){
			draw shape color: #brown;
		} else if (new_normal){
			draw shape color: #orange;
		} else {
			draw shape color: #turquoise;
		}*/
	}
}

species Roads {
	aspect geom {
		draw shape color: #orange;
	}
}
