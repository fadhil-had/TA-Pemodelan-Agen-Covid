/**
* Name: tugasAkhirAzka
* Based on the internal empty template. 
* Author: PRINCE
* Tags: 
*/


model tugasAkhirAzka

/* Insert your model definition here */

import "init_Azka.gaml"
import "reflex_global_Azka.gaml"
import "agen_Azka.gaml"

global {
	init {
		do user_inputs;
		do init_building;
		do init_jobtype;
		do init_hospital;
		do population_generation;
		do major_agenda;
		do assign_major_agenda;
		ask num_init_infected among Individual {
			covid_stat <- "exposed";
		}
	}
	
	action user_inputs {
		map<string,unknown> values1 <- user_input("Masukkan jumlah hari yang akan disimulasikan.",[enter("Hari",60)]);
		simulation_days <- int(values1 at "Hari");
		map<string,unknown> values2 <- user_input("Masukkan jumlah keluarga di pemodelan.",[enter("Keluarga",10000)]);
		num_family <- int(values2 at "Keluarga");
		map<string,unknown> values3 <- user_input("Masukkan jumlah individu terinfeksi di awal.",[enter("Jumlah",500)]);
		num_init_infected <- int(values3 at "Jumlah");
		//Hospital
		map<string,unknown> values4 <- user_input("Masukkan kapasitas total rumah sakit saat simulasi untuk ruangan non-ICU.",[enter("Jumlah",100)]);
		patient_cap <- int(values4 at "Jumlah");
		map<string,unknown> values5 <- user_input("Masukkan kapasitas total rumah sakit saat simulasi untuk ruangan ICU tanpa Ventilator.",[enter("Jumlah",15)]);
		icu_cap <- int(values5 at "Jumlah");
		map<string,unknown> values6 <- user_input("Masukkan kapasitas total rumah sakit saat simulasi untuk ruangan ICU dengan Ventilator.",[enter("Jumlah",15)]);
		ven_cap <- int(values6 at "Jumlah");
		map<string,unknown> values7 <- user_input("Masukkan persen batasan penambahan kapasitas rumah sakit relatif terhadap total penderita COVID.",[enter("%",50)]);
		hospital_threshold <- float(values7 at "%");
		
		map<string,unknown> values11 <- user_input("Masukkan persen efektivitas contact tracing.",[enter("(%)",100)]);
		contact_tracing_effectiveness <- int(values11 at "(%)")/100.0;
		map<string,unknown> values12 <- user_input("Masukkan persen efektivitas test relatif terhadap sensitivitas dan spesifisitas tes.",[enter("(%)",100)]);
		test_accuracy <- int(values12 at "(%)")/100.0;
		map<string,unknown> values13 <- user_input("Masukkan persen kepatuhan orang2 secara umum.",[enter("(%)",100)]);
		obedience <- int(values13 at "(%)")/100.0;
	}
	
		reflex stop_simulation when: (current_day = simulation_days) {
		do pause;
	}
}
/* Insert your model definition here */
experiment "Run experiment" type: gui autorun:true {
	bool allow_rewrite <- true;
	string filename_1 <- "save_data_klinis_harian_" + cur_date_str + ".csv";
	string filename_2 <- "save_data_klinis_total_" + cur_date_str + ".csv";
	string filename_3 <- "save_data_sosioekonomi_total_" + cur_date_str + ".csv";
	reflex output_file when: current_hour = 0 {
		// Refleks untuk mengatur data apa saja yang dioutputkan ke file .csv output.
		save [string(current_day), positive_today, confirmed_today, recovered_today, death_today] to: filename_1 type:csv rewrite:allow_rewrite;
		allow_rewrite <- false;
		save [string(current_day), num_confirmed, num_positive, num_suspect, num_probable, num_discarded, num_recovered, num_death, num_hospitalized, num_ICU] to: filename_2 type:csv rewrite:allow_rewrite;
		allow_rewrite <- false;
		save [string(current_day), positive_today, confirmed_today, recovered_today, death_today] to: filename_3 type:csv rewrite:allow_rewrite;
		allow_rewrite <- false;
	}
	
	string simulation_name <- "Hari " + hari_apa + " jam " + current_hour
	update: "Hari " + hari_apa + " jam " + current_hour;
	string legend <- ("Kuning: Suspect; Jingga: Probable; Merah: Confirmed; Biru: Discarded; Hitam: Mati; Hijau: Sehat; Putih: Normal");
	output {
		layout #split consoles:false editors:false navigator:false;
		
		display chart_1 refresh:(current_hour = 0) {
			chart "Data harian" type: xy background: #white axes:#black color: #black tick_line_color: #grey {
				data "Jumlah Individu yang sebenarnya positif pada hari ini"
					value: {current_day, positive_today} color: #orange line_visible:false;
				data "Jumlah Individu yang dinyatakan positif pada hari ini"
					value: {current_day, confirmed_today} color: #red line_visible:false;
				data "Jumlah Individu yang meninggal pada hari ini"
					value: {current_day, death_today} color: #green line_visible:false;
				data "Jumlah Individu yang sembuh pada hari ini"
					value: {current_day, recovered_today} color: #blue line_visible:false;
			}
		}
		
		display view draw_env:false type:opengl {
			
			species Boundary aspect:geom;
			species Roads aspect:geom;
			species Building aspect:geom;
			species Individual aspect:circle;
			graphics title {
				draw simulation_name color: #black anchor: #top_center;
				draw legend color: #black anchor: #bottom_center;
			}
		}
		
		display chart_2 refresh:(current_hour = 0) {
			chart "Data total status" type: xy background: #white axes:#white color: #black tick_line_color: #grey{
				data "Jumlah Individu terinfeksi dalam kenyataannya"
					value: {cycle/24, num_positive} color: #black marker:false;
				data "Jumlah Individu terkonfirmasi hasil test"
					value: {cycle/24, num_confirmed} color: #red marker:false;	
				data "Jumlah Individu berstatus suspect"
					value: {cycle/24, num_suspect} color: #yellow marker:false;
				data "Jumlah Individu berstatus probable"
					value: {cycle/24, num_probable} color: #purple marker:false;
				data "Jumlah Individu berstatus discarded"
					value: {cycle/24, num_discarded} color: #blue marker:false;
				}
		}
		
		display chart_3 refresh:(current_hour = 0) {
			chart "Data sembuh dan meninggal" type: xy background: #white axes:#white color: #black tick_line_color: #grey{
				data "Jumlah Individu dirawat di rumah sakit"
					value: {cycle/24, num_hospitalized} color: #green marker:false;
				data "Jumlah Individu dirawat di ICU"
					value: {cycle/24, num_ICU} color: #orange marker:false;
				data "Jumlah Individu yang sembuh"
					value: {cycle/24, num_recovered} color: #blue marker:false;
				data "Jumlah Individu yang meninggal"
					value: {cycle/24, num_death} color: #red marker:false;
				}
		}
		
		display chart_4 refresh:(current_hour = 0) {
			chart "Data status perjalanan" type: xy background: #white axes:#white color: #black tick_line_color: #grey{
				data "Jumlah Individu keluar dari kota"
					value: {cycle/24, num_travel} color: #blue marker:false;
				}
		}
		
		display chart_5 refresh:(current_hour = 0) {
			chart "Data status ekonomi" type: xy background: #white axes:#white color: #black tick_line_color: #grey{
				data "Jumlah Individu yang masuk kategori miskin"
					value: {cycle/24, num_poor} color: #red marker:false;
				data "Jumlah keluarga yang masuk kategori miskin"
					value: {cycle/24, num_family_poor} color: #green marker:false;
				}
		}
	}
}