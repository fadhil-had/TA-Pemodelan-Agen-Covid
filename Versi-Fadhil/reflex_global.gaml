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
	int confirmed_temp <- 0;
	
	int pos_decrease_counter <- 0;
	int param_mobility <- 0;
	
	
	reflex update_data when: current_hour = 23 {
		/*
		 * reflex untuk update data jumlah Individu terinfeksi, Individu di rumah sakit,
		 * dan lain-lain. Dilakukan pada jam 23 karena pada jam 0, data akan didisplay
		 * pada grafik di experiment.gaml.
		 */
		
		num_suspect <- population count (each.stat_covid in suspect and each.live);
		num_probable <- population count (each.stat_covid in probable);
		num_confirmed <- population count (each.stat_covid in confirmed and each.live);
		num_discarded <- population count (each.stat_covid in discarded);
		num_recovered <- population count (each.stat_covid in recovered and each.live);
		num_death <- population count (each.stat_covid in death and each.live);
		num_positive <- population count (each.covid_stat in infected and each.live);
		num_hospitalized <- population count (each.quarantine_place = hospital and each.live);
		num_ICU <- population count (each.quarantine_place = ICU and each.live);
		num_travel <- population count (each.stat_traveler in leave and each.live);
		num_poor <- population count (each.poor and each.live);
		num_family_poor <- Building count (each.type in [possible_livings] and each.family_poor);
		
		confirmed_today <- population count (each.stat_covid in confirmed and each.quarantine_period < 20 and each.live);
		positive_today <- population count (each.covid_stat in [infected] and (each.infection_period-each.incubation_period+24) < 24 and (each.infection_period-each.incubation_period+24) >= 0 and each.live);
		recovered_today <- num_recovered - recovered_temp;
		death_today <- num_death - death_temp;
		hospitalized_today <- population count ((each.quarantine_place in [hospital,ICU]) and each.quarantine_period < 24 and each.live);
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
		confirmed_temp <- num_confirmed;
		
		positive_yesterday <- positive_today;
		
		if (travel_today/num_population > 0.001){
			param_mobility <- param_mobility + 1;
		} else {
			param_mobility <- 0;
		}
	}	
	
	reflex total_lockdown when: num_confirmed >= lockdown_threshold and not lockdown and (param_mobility > mobility_lockdown) { //https://www.pikiran-rakyat.com/nasional/pr-01352541/pakar-ui-sebut-ada-3-kriteria-yang-perlu-dilihat-menuju-indonesia-lockdown-dalam-mencegah-corona
		//Syarat lockdown 3, jumlah kasus meningkat pesat, mobilitas tinggi dan dana siap
		time_of_day <- [];
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
						if (occupation = "wiraswasta"){
							covid_salary <- rnd(0.0,salary*0.5);
						} else if (occupation in ["swasta_free","swasta_office","industrial","bumn"]){
							covid_salary <- salary*0.5;
						} else if (occupation in ["pns"]){
							covid_salary <- salary*0.8;
						}
					}
				}
			}
		}
		lockdown <- true;
		psbb <- false;
		new_normal <- false;
		activity_reduction_factor <- activity_reduction_lockdown;
		mask_usage_proportion <- 1.0;
	}
	
	reflex psbb when: num_confirmed >= psbb_threshold and not lockdown and not psbb { //https://www.pikiran-rakyat.com/nasional/pr-01352541/pakar-ui-sebut-ada-3-kriteria-yang-perlu-dilihat-menuju-indonesia-lockdown-dalam-mencegah-corona
		/* 
		 * Kalau sedang lockdown, gabisa langsung PSBB, tp harus ke new normal dulu
		 * Jam malam diberlakukan sehingga diatas jam 8 gaboleh keluar sama sekali
		 */
		
		night <- [19,20];
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
			} else if (occupation in ["wiraswasta"]){
				ask individuals_per_profession[occupation] {
					loop agenda_day over:agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[start_hour] <- major_agenda_place;
						covid_salary <- rnd(salary*0.25,salary*0.75); 
					}
				}
			} else if (occupation in ["indusrial","pns","police"]){
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
					covid_salary <- rnd(salary*0.5,salary*0.8); 
				}
			}
			else {
				// Menyuruh Individual yang bekerja di selain nakes full wfh
				ask individuals_per_profession[occupation] {
					loop agenda_day over:agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[start_hour] <- home;
						covid_salary <- rnd(salary*0.5,salary*0.8); 
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
		}
		lockdown <- false;
		psbb <- true;
		new_normal <- false;
		activity_reduction_factor <- activity_reduction_psbb;
		mask_usage_proportion <- 0.75;
	}
	
	reflex new_normal when: pos_decrease_counter = new_normal_threshold and num_confirmed < psbb_threshold and (lockdown or psbb) and not new_normal {
		
		/*
		 * PSBB sama lockdown diangkat jika point mencapai threshold
		 * Nakes kembali kerja normal, pekerja kantoran selain wiraswasta dan pekerja lepas 3 hari wfh
		 * Sisanya kerja normal
		 */
		
		night <- [19,20,21,22];
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
			} else if (occupation != ["none","wiraswasta","industrial","swasta_free","police"]){
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
					covid_salary <- rnd(salary*0.75,salary);
				}
			} else {
				ask individuals_per_profession[occupation] {
					loop agenda_day over: agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[start_hour] <- major_agenda_place;
						covid_salary <- salary; 
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
		psbb <- false;
		new_normal <- true;
		activity_reduction_factor <- activity_reduction_newnormal;
		mask_usage_proportion <- 0.5;
	}
	
	reflex full_normal when: confirmed_today = 0 and pos_decrease_counter = normal_threshold and (lockdown or psbb or new_normal) {
		
		/*
		 * Melakukan pengangkatan lockdown ketika counter penurunan
		 * jumlah positif mencapai threshold.
		 * Tiap Individual yang bekerja tidak di rumah sakit dapat 
		 * bekerja kembali seperti biasa.
		 */
		
		night <- [19,20,21,22];
		loop occupation over: individuals_per_profession.keys {
			if (occupation != none){
				ask individuals_per_profession[occupation] {
					loop agenda_day over: agenda_week {
						int start_hour <- min(agenda_day.keys);
						agenda_day[start_hour] <- major_agenda_place;
					}
				}
			}
		}
		loop places over: buildings_per_activity.keys{
			if (places = one_of(possible_minors)){
				ask buildings_per_activity[places]{
					capacity <- capacity*2;
				}	
			}
		}
		lockdown <- false;
		psbb <- false;
		new_normal <- false;
		activity_reduction_factor <- 0.0;
		mask_usage_proportion <- 0.0;
	}
}