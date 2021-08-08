/**
* Name: tugasAkhir
* Tolong dicek apakah bisa untuk menentukan Confusion Matrix.
* Author: Fadhil
* Tags: 
*/


model tugasAkhir

import "init.gaml"
import "agen.gaml"
import "parameter.gaml"

/* Insert your model definition here */

global {
	
	float proba_travel <- proba_travel;
	float proba_travel_family <- proba_active_family*proba_travel; //Peluang satu keluarga melakukan travelling
	int num_suspect <- 0;
	int num_probable <- 0;
	int num_confirmed <- 0;
	int num_discarded <- 0;
	int num_recovered <- 0;
	int num_death <- 0;
	int num_positive <- 0; //Real (Sebagai Tuhan)
	int num_hospitalized <- 0;
	int num_ICU <- 0;
	int num_travel <- 0;
	int num_come <- 0;
	int num_poor <- 0;
	int num_family_poor <- 0;
	
	int confirmed_today <- 0;
	int positive_today <- 0;
	int recovered_today <- 0;
	int death_today <- 0;
	int hospitalized_today <- 0;
	int travel_today <- 0;
	
	int positive_yesterday <- 0;
	int confirmed_yesterday <- 0;
	int recovered_yesterday <-0;
	int hospitalized_yesterday <- 0;
	
	int recovered_temp <- 0;
	int death_temp <- 0;
	int travel_temp <- 0;
	
	//int total_testst <- 0;
	
	int pos_decrease_counter <- 0;
	int param_mobility <- 0;
	
	map<int, int> count_today;
	int come_today <- 0;
	int come_weekly <- 0;
	int average_come <- 0;
	
	
	reflex travel_coming when : (current_hour = 20 and flip(proba_travel) and not lockdown) { //Jika jam 8 malam dan flip proba maka dibuat individual
		int num_family_traveler <- rnd(20,100);
		int limit_travel_group <- rnd(7,21);
		if (psbb) {
			num_family_traveler <- rnd(20,50); //Jika PSBB maka jumlah keluarga yang datang dibatasi jadi maksimal 50 per hari
			int limit_travel_group <- rnd(7,14); //Waktu juga dikurangi seminggu
		}
		loop times: num_family_traveler {
			ask one_of(buildings_per_activity["hotel"]){ //Pilih salah satu hotel
				if (flip(proba_travel_family)) { //Buat individu
				
					create Individual {
						age <- rnd(min_working_age,max_working_age);
						sex <- 1;
						home <- myself;
						myself.residents << self;
						traveler_days <- limit_travel_group;
						stat_traveler <- come;
					}
				
					create Individual {
						age <- rnd(min_working_age,max_working_age);
						sex <- 0;
						home <- myself;
						myself.residents << self;
						traveler_days <- limit_travel_group;
						stat_traveler <- come;
					}
				
					int num_children <- rnd(0,max_num_children);
					loop times: num_children {
						create Individual {
							age <- rnd(min_age,max_student_age);
							sex <- rnd(0,1);
							home <- myself;
							myself.residents << self;
							traveler_days <- limit_travel_group;
							stat_traveler <- come;
						}
					}
				
					if (flip(proba_grandfather)) {
						create Individual {
							age <- rnd(max_working_age+1,max_age);
							sex <- 1;
							home <- myself;
							myself.residents << self;
							traveler_days <- limit_travel_group;
							stat_traveler <- come;
						}
					}
				
					if(flip(proba_grandmother)) {
						create Individual {
							age <- rnd(max_working_age+1,max_age);
							sex <- 0;
							home <- myself;
							myself.residents << self;
							traveler_days <- limit_travel_group;
							stat_traveler <- come;
						}
					}
				
					if(flip(proba_others)) {
						create Individual {
							age <- rnd(min_working_age,max_working_age);
							sex <- rnd(0,1);
							home <- myself;
							myself.residents << self;
							traveler_days <- limit_travel_group;
							stat_traveler <- come;
						}
					}
				
				} else {
					// Individual yang datang sendirian
					
					create Individual {
						age <- rnd(min_working_age,max_age);
						sex <- rnd(0,1);
						home <- myself;
						myself.residents << self;
						traveler_days <- limit_travel_group;
						stat_traveler <- come;
					}
				}
			}
		}
		come_today <- length(Individual) - num_population;
	}

	reflex bye_traveler when : (current_hour = 19){ //Ini fungsi untuk test apakah mereka akan pergi atau ga wkwk, belum pasti
		ask Individual where (each.stat_traveler = come and each.traveler_days = 0){
			do die;
		}
	}
	
	reflex update_data when: current_hour = 23 {
		/*
		 * reflex untuk update data jumlah Individu terinfeksi, Individu di rumah sakit,
		 * dan lain-lain. Dilakukan pada jam 23 karena pada jam 0, data akan didisplay
		 * pada grafik di experiment.gaml.
		 */
		
		num_suspect <- population count (each.stat_covid in suspect);
		num_probable <- population count (each.stat_covid in probable);
		num_confirmed <- population count (each.stat_covid in confirmed);
		num_discarded <- population count (each.stat_covid in discarded);
		num_recovered <- population count (each.stat_covid in recovered);
		num_death <- population count (each.stat_covid in death);
		num_positive <- population count (each.covid_stat);
		num_hospitalized <- population count (each.quarantine_place = hospital);
		num_ICU <- population count (each.quarantine_place = ICU);
		num_travel <- population count (each.stat_traveler in leave);
		num_come <- population count (each.stat_traveler in come);
		num_poor <- population count (each.poor);
		num_family_poor <- Building count (each.type = home and each.family_poor);
		
		confirmed_today <- population count (each.stat_covid in [confirmed] and each.infection_period < 24);
		positive_today <- population count (each.covid_stat and each.infection_period < 24);
		recovered_today <- num_recovered - recovered_temp;
		death_today <- num_death - death_temp;
		hospitalized_today <- population count ((each.quarantine_place in [hospital,ICU]) and each.quarantine_period < 24);
		travel_today <- num_travel - travel_temp;
		
		// Untuk melihat kualitas layanan sebagai syarat dari lockdown, masih akan dikaji
		if (positive_today < positive_yesterday and hospitalized_today < hospitalized_yesterday and recovered_today > recovered_yesterday) {
			pos_decrease_counter <- pos_decrease_counter + 1;
		} else { // Reset counter
			pos_decrease_counter <- 0;
		}
		
		positive_yesterday <- positive_today;
		hospitalized_yesterday <- hospitalized_today;
		confirmed_yesterday <- confirmed_today;
		recovered_temp <- num_recovered;
		recovered_yesterday <- recovered_today;
		death_temp <- num_death;
		travel_temp <- num_travel;
		
		positive_yesterday <- positive_today;
		
		int d <- current_day_of_week;
		come_weekly <- come_weekly - count_today[d]; //Kurangi dengan hari minggu lalu
		count_today[d] <- come_today; //Ganti isi hari minggu lalu dengan minggu ini
		come_weekly <- come_weekly + count_today[d]; //Tambahin ke come weekly
		average_come <- come_weekly div 7; //Rata2in deh
		
		if (travel_today div num_population > 0.1 and average_come > 300){
			param_mobility <- param_mobility + 1;
		} else {
			param_mobility <- 0;
		}
	}	
	
	reflex total_lockdown when: num_confirmed >= lockdown_threshold and not lockdown and (param_mobility > mobility_lockdown) { //https://www.pikiran-rakyat.com/nasional/pr-01352541/pakar-ui-sebut-ada-3-kriteria-yang-perlu-dilihat-menuju-indonesia-lockdown-dalam-mencegah-corona
		//Syarat lockdown 3, jumlah kasus meningkat pesat, mobilitas tinggi dan dana siap
		loop occupation over: individuals_per_profession.keys {
			if (occupation = "nakes") {
				// Menyuruh Individual yang bekerja di nakes
				// Untuk kerja fullday dan karantina di RS
				ask individuals_per_profession[occupation] {					
					loop agenda_day over:agenda_week {
						int start_hour <- 0;
						int end_hour <- 23;						
						agenda_day[start_hour] <- major_agenda_place; //Setiap hari 24 jam nakes dirumah sakit
						agenda_day[end_hour] <- major_agenda_place;
					}
				}
			} else {
				// Menyuruh Individual yang bekerja di selain nakes full wfh
				ask individuals_per_profession[occupation] {
					loop agenda_day over:agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[start_hour] <- home;
					}
				}
			}
		}
		lockdown <- true;
		new_normal <- false;
		activity_reduction_factor <- 0.75;
		mask_usage_proportion <- 0.9;
		infection_reduction_factor <- 0.25;
	}
	
	reflex psbb when: num_confirmed >= psbb_threshold and num_confirmed < lockdown_threshold and not lockdown and not psbb { //https://www.pikiran-rakyat.com/nasional/pr-01352541/pakar-ui-sebut-ada-3-kriteria-yang-perlu-dilihat-menuju-indonesia-lockdown-dalam-mencegah-corona
		//Kalau sedang lockdown, gabisa langsung PSBB, tp harus ke new normal dulu
		loop occupation over: individuals_per_profession.keys {
			if (occupation = "nakes") {
				// Menyuruh Individual yang bekerja di nakes
				// Untuk kerja fullday dan karantina di RS
				ask individuals_per_profession[occupation] {					
					loop agenda_day over:agenda_week {
						int start_hour <- min(agenda_day.keys);
						int end_hour <- max(agenda_day.keys);						
						agenda_day[start_hour] <- major_agenda_place; //Setiap hari 24 jam nakes dirumah sakit
						agenda_day[end_hour] <- home;
					}
				}
			} else {
				// Menyuruh Individual yang bekerja di selain nakes full wfh
				ask individuals_per_profession[occupation] {
					loop agenda_day over:agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[start_hour] <- home;
					}
				}
			}
		}
		lockdown <- true;
		new_normal <- false;
		activity_reduction_factor <- activity_reduction_psbb;
		mask_usage_proportion <- 0.9;
	}
	
	reflex new_normal when: pos_decrease_counter = new_normal_threshold and (lockdown or psbb) and not new_normal {
		
		/*
		 * Melakukan pengangkatan lockdown ketika counter penurunan
		 * jumlah positif mencapai threshold.
		 * Tiap Individual yang bekerja tidak di rumah sakit dapat 
		 * bekerja kembali seperti biasa.
		 */
		
		loop occupation over: individuals_per_profession.keys {
			if (occupation = "nakes") {
				ask individuals_per_profession[occupation] {
					loop agenda_day over: agenda_week {
						int start_hour <- min(agenda_day.keys);
						int end_hour <- max(agenda_day.keys);
						agenda_day[start_hour] <- major_agenda_place;
						agenda_day[end_hour] <- home;
					}
				}
			} else if (occupation != ["none","wiraswasta","industrial"]){
				ask individuals_per_profession[occupation] {					
					int wfh_day_1 <- one_of (major_agenda_hours.keys);
					int wfh_day_2 <- one_of (major_agenda_hours.keys - wfh_day_1);
					int wfh_day_3 <- one_of (major_agenda_hours.keys - wfh_day_1 - wfh_day_2);
					int start_hour <- min(major_agenda_hours[wfh_day_1]);
					agenda_week[wfh_day_1][start_hour] <- home;
					start_hour <- min(major_agenda_hours[wfh_day_2]);
					agenda_week[wfh_day_2][start_hour] <- home;
					start_hour <- min(major_agenda_hours[wfh_day_3]);
					agenda_week[wfh_day_3][start_hour] <- home;
				}
			} else {
				ask individuals_per_profession[occupation] {
					loop agenda_day over: agenda_week {
						int end_hour <- max(agenda_day.keys);
						agenda_day[end_hour] <- home;
					}
				}
			}
		}
		loop places over: buildings_per_activity.keys{
			if (places = one_of(possible_minors)){
				ask buildings_per_activity[places]{
					capacity <- capacity div 2;
				}	
			}
		}

		lockdown <- false;
		new_normal <- true;
		activity_reduction_factor <- 0.5;
		mask_usage_proportion <- 0.5;
	}
	
	reflex full_normal when: pos_decrease_counter = normal_threshold and (lockdown or psbb or new_normal) {
		
		/*
		 * Melakukan pengangkatan lockdown ketika counter penurunan
		 * jumlah positif mencapai threshold.
		 * Tiap Individual yang bekerja tidak di rumah sakit dapat 
		 * bekerja kembali seperti biasa.
		 */
		
		loop occupation over: individuals_per_profession.keys {
			if (occupation = "nakes") {
				ask individuals_per_profession[occupation] {
					loop agenda_day over: agenda_week {
						int end_hour <- max(agenda_day.keys);
						agenda_day[end_hour] <- home;
					}
				}
			} else if (occupation != none){
				ask individuals_per_profession[occupation] {
					loop agenda_day over: agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[start_hour] <- major_agenda_place;
					}
				}
			}
		}
		lockdown <- false;
		new_normal <- false;
		activity_reduction_factor <- 0.0;
		mask_usage_proportion <- 0.0;
	}
}