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
	
	float proba_travel_family <- 0.01; //Peluang satu keluarga melakukan travelling
	int num_suspect <- 0;
	int num_probable <- 0;
	int num_confirmed <- 0;
	int num_discarded <- 0;
	int num_recovered <- 0;
	int num_death <- 0;
	int num_positive <- 0; //Real (Sebagai Tuhan)
	int num_hospitalized <- 0;
	int num_travel <- 0;
	
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
	
	reflex update_data when: current_hour = 23 {
		/*
		 * reflex untuk update data jumlah Individu terinfeksi, Individu di rumah sakit,
		 * dan lain-lain. Dilakukan pada jam 23 karena pada jam 0, data akan didisplay
		 * pada grafik di experiment.gaml.
		 */
		 
		num_suspect <- Individual count (each.stat_covid in suspect and each.live);
		num_probable <- Individual count (each.stat_covid in probable);
		num_confirmed <- Individual count (each.stat_covid in confirmed and each.live);
		num_discarded <- Individual count (each.stat_covid in discarded and each.live);
		num_recovered <- Individual count (each.stat_covid in recovered and each.live);
		num_death <- Individual count (each.stat_covid in death);
		num_positive <- Individual count (each.covid_stat);
		num_hospitalized <- Individual count (each.quarantine_status = "hospital" and each.live);
		num_travel <- Individual count (each.stat_traveler in leave);
		
		confirmed_today <- Individual count (each.stat_covid in [confirmed] and each.infection_period < 24 and each.live);
		positive_today <- Individual count (each.covid_stat and each.infection_period < 24 and each.live);
		recovered_today <- num_recovered - recovered_temp;
		death_today <- num_death - death_temp;
		hospitalized_today <- Individual count (each.quarantine_status = "hospital" and each.quarantine_period < 24 and each.live);
		travel_today <- num_travel - travel_temp;
		
		// Untuk melihat kualitas layanan sebagai syarat dari lockdown, masih akan dikaji
		if (positive_today < positive_yesterday and hospitalized_today < hospitalized_yesterday and recovered_today > recovered_yesterday) {
			pos_decrease_counter <- pos_decrease_counter + 1;
		} else { // Reset counter
			pos_decrease_counter <- 0;
		}
		
		if (travel_today div num_population = 0.1){
			param_mobility <- param_mobility + 1;
		} else {
			param_mobility <- 0;
		}
		
		positive_yesterday <- positive_today;
		hospitalized_yesterday <- hospitalized_today;
		confirmed_yesterday <- confirmed_today;
		recovered_temp <- num_recovered;
		recovered_yesterday <- recovered_today;
		death_temp <- num_death;
		travel_temp <- num_travel;
	}	
	
	reflex total_lockdown when: num_confirmed >= lockdown_threshold and not lockdown and not new_normal and param_mobility > mobility_lockdown { //https://www.pikiran-rakyat.com/nasional/pr-01352541/pakar-ui-sebut-ada-3-kriteria-yang-perlu-dilihat-menuju-indonesia-lockdown-dalam-mencegah-corona
		//Syarat lockdown 3, jumlah kasus meningkat pesat, mobilitas tinggi dan dana siap
		loop occupation over: individuals_per_profession.keys {
			if (occupation = "nakes") {
				// Menyuruh Individual yang bekerja di nakes
				// Untuk kerja fullday dan karantina di RS
				ask individuals_per_profession[occupation] {					
					loop agenda_day over:agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[time_of_day] <- major_agenda_place; //Setiap hari 24 jam nakes dirumah sakit
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
		activity_reduction_factor <- 0.75;
		mask_usage_proportion <- 0.9;
		infection_reduction_factor <- 0.25;
		building_capacity_factor <- 0.1;
	}
	
	reflex new_normal when: pos_decrease_counter = new_normal_threshold and lockdown and not new_normal and not full_normal {
		
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
			if (places = possible_minors){
				ask buildings_per_activity[places]{
					capacity <- capacity div 2;
				}	
			}
		}

		lockdown <- false;
		new_normal <- false;
		full_normal <- true;
		activity_reduction_factor <- 0.5;
		mask_usage_proportion <- 0.5;
		infection_reduction_factor <- 0.15; //Ini gaada datanya
	}
	
	reflex full_normal when: pos_decrease_counter = normal_threshold and (lockdown or new_normal) {
		
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
		full_normal <- true;
		activity_reduction_factor <- 0.0;
		mask_usage_proportion <- 0.0;
		infection_reduction_factor <- 0.0; //Ini gaada datanya
	}
}