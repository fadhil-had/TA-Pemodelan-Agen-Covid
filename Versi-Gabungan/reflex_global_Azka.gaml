/**
* Name: tugasAkhirAzka
* Based on the internal empty template. 
* Author: PRINCE
* Tags: 
*/


model tugasAkhirAzka

/* Insert your model definition here */

import "init_Azka.gaml"
import "agen_Azka.gaml"
import "parameter_Azka.gaml"

/* Insert your model definition here */

global {
	
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
	
	// PARAMETER HEALTH SUPPLY
	//HCW
	int ideal_hcw;
	int real_hcw;
	int total_hcw;
	int sick_hcw;
	float hcw_factor;
	int hcw_per_bed <- 3;
	//BED & Ventilator
	int total_moderate_bed;
	int total_severe_bed;
	int total_critical_bed;
	int total_severe_icu;
	int total_critical_icu;
	int total_critical_venti;
	int total_bed;
	int total_icu;
	//O2
	int o2_severe_factor <- rnd(5,15);
	float total_o2;
	int o2_critical_factor <- 30;
	//PPE
	int total_ppe <- 0;
	
	
	reflex update_data when: current_hour = 22 {
		/*
		 * reflex untuk update data jumlah Individu terinfeksi, Individu di rumah sakit,
		 * dan lain-lain. Dilakukan pada jam 23 karena pada jam 0, data akan didisplay
		 * pada grafik di experiment.gaml.
		 */
		
		num_suspect <- population count (each.stat_covid in "suspect" and each.live);
		num_probable <- population count (each.stat_covid in "probable");
		num_confirmed <- population count (each.stat_covid in "confirmed" and each.live);
		num_discarded <- population count (each.stat_covid in "discarded");
		num_recovered <- population count (each.stat_covid in "recovered" and each.live);
		num_death <- population count (each.stat_covid in "death" and each.live);
		num_positive <- population count (each.covid_stat in "infected" and each.live);
		num_hospitalized <- population count (each.s_quarantine_place = "hospital" and each.live);
		num_ICU <- population count (each.s_quarantine_place = "ICU" and each.live);
		num_travel <- population count (each.stat_traveler in "leave" and each.live);
		
		confirmed_today <- population count (each.stat_covid in confirmed and each.quarantine_period < 20 and each.live);
		positive_today <- population count (each.covid_stat in [infected] and (each.infection_period-each.incubation_period+24) < 24 and (each.infection_period-each.incubation_period+24) >= 0 and each.live);
		recovered_today <- num_recovered - recovered_temp;
		death_today <- num_death - death_temp;
		hospitalized_today <- population count ((each.quarantine_place in [hospital,ICU]) and each.quarantine_period < 24 and each.live);
		travel_today <- num_travel - travel_temp;
		
		positive_yesterday <- positive_today;
		hospitalized_yesterday <- hospitalized_today;
		confirmed_yesterday <- confirmed_today;
		recovered_temp <- num_recovered;
		recovered_yesterday <- recovered_today;
		death_temp <- num_death;
		travel_temp <- num_travel;
		confirmed_temp <- num_confirmed;
		
		positive_yesterday <- positive_today;
		
	}
	
	reflex health_supply when: current_hour = 23 {
		//BED & Ventilator
		total_moderate_bed <- population count (each.s_quarantine_place in "hospital" and each.live and each.severity in "moderate");
		total_severe_bed <- population count (each.s_quarantine_place in "hospital" and each.live and each.severity in "severe");
		total_critical_bed <- population count (each.s_quarantine_place in "hospital" and each.live and each.severity in "critical");
		total_severe_icu <- population count (each.s_quarantine_place in "ICU" and each.live and each.severity in "severe");
		total_critical_icu <- population count (each.s_quarantine_place in "ICU" and each.live and each.severity in "critical");
		total_critical_venti <- population count (each.s_quarantine_place in "ICU Venti" and each.live);
		total_bed <- total_moderate_bed + total_severe_bed + total_critical_bed;
		total_icu <- total_severe_icu + total_critical_icu;
		
		//Add Hospital Capacity
		if ((total_bed + total_icu) > hospital_threshold*(patient_cap+icu_cap+ven_cap)) {
			do plus_hospital_capacity;
		} 
			
		//HCW
		sick_hcw <- population count (each.quarantine_status and each.major_agenda_type in "nakes");
		real_hcw <- total_hcw - sick_hcw;
		ideal_hcw <- hcw_per_bed * (total_bed + total_icu); 
		hcw_factor <- (ideal_hcw-real_hcw) / ideal_hcw; 
		
		//O2
		total_o2 <- (o2_severe_factor*1440*0.001*(total_moderate_bed + total_severe_bed + total_severe_icu)) +(o2_critical_factor*1440*0.001*(total_critical_bed+total_critical_icu+total_critical_venti));
		
		//PPE
		total_ppe <- total_ppe + real_hcw;
		
	}
	
	action plus_hospital_capacity {
		float add_factor <- rnd(1.1, 2.0);
		patient_cap <- int(patient_cap*add_factor);
		icu_cap <- int(icu_cap*add_factor);
		ven_cap <- int(ven_cap*add_factor);
		total_hospital <- Building count (each.type in "hospital");
		int temp_patient <- int(patient_cap div total_hospital);
		int temp_icu <- int(icu_cap div total_hospital);
		int temp_ven <- int(ven_cap div total_hospital);
		
		ask hospitals{
			patient_capacity <- temp_patient;
			icu_capacity <- temp_icu;
			icu_venti_capacity <- temp_ven; 
		}
	} 
	
	//bikin reflex kalo rumah sakit melebihi threshold
}