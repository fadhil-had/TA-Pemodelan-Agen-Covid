/**
* Name: tugasAkhir
* Based on the internal empty template. 
* Author: Fadhil
* Tags: 
*/


model tugasAkhir

import "init.gaml"
import "fungsi.gaml"
import "reflex_global.gaml"

global {
	init {
		do init_building;
		do init_jobtype;
		do population_generation;
		do major_agenda;
		do assign_major_agenda;
		do user_inputs;
		ask num_init_infected among Individual {
			covid_stat <- true;
		}
	}
	
	action user_inputs {
		map<string,unknown> values1 <- user_input("Masukkan jumlah hari yang akan disimulasikan.",[enter("Hari",60)]);
		simulation_days <- int(values1 at "Hari");
		map<string,unknown> values2 <- user_input("Masukkan jumlah keluarga di pemodelan.",[enter("Keluarga",1000)]);
		num_family <- int(values2 at "Keluarga");
		map<string,unknown> values3 <- user_input("Masukkan jumlah individu terinfeksi di awal.",[enter("Jumlah",5)]);
		num_init_infected <- int(values3 at "Jumlah");
		map<string,unknown> values4 <- user_input("Masukkan berapa threshold jumlah pasien yang terkonfirmasi sehingga terjadi lockdown.",[enter("Orang",100)]);
		lockdown_threshold <- int(values4 at "Orang");
		map<string,unknown> values5 <- user_input("Masukkan berapa threshold jumlah pasien yang terkonfirmasi sehingga terjadi PSBB.",[enter("Orang",50)]);
		lockdown_threshold <- int(values5 at "Orang");
		map<string,unknown> values6 <- user_input("Masukkan berapa threshold nilai keberhasilan atau hari penurunan sehingga terjadi new normal.",[enter("batas",5)]);
		lockdown_threshold <- int(values6 at "batas");
		map<string,unknown> values7 <- user_input("Masukkan berapa hari terjadi penurunan konfirmasi positif sampai dianggap normal",[enter("Hari",100)]);
		new_normal_threshold <- int(values7 at "Hari");
		map<string,unknown> values8 <- user_input("Masukkan persen efektivitas contact tracing.",[enter("(%)",100)]);
		contact_tracing_effectiveness <- int(values8 at "(%)")/100.0;
		map<string,unknown> values9 <- user_input("Masukkan persen pengurangan aktivitas selama pandemi.",[enter("(%)",100)]);
		contact_tracing_effectiveness <- int(values9 at "(%)")/100.0;
	}
	
		reflex stop_simulation when: (current_day = simulation_days) {
		do pause;
	}
}
/* Insert your model definition here */
experiment "Run experiment" type: gui autorun:true {
	bool allow_rewrite <- true;
	string filename <- "save_data_harian_" + cur_date_str + ".csv";
	reflex output_file when: current_hour = 0 {
		// Refleks untuk mengatur data apa saja yang dioutputkan ke file .csv output.
		save [string(current_day), confirmed_today, positive_today, recovered_today, death_today] to: filename type:csv rewrite:allow_rewrite;
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
					value: {cycle/24, num_ICU} color: #orange marker:false;
				data "Jumlah Individu berstatus discarded"
					value: {cycle/24, num_ICU} color: #blue marker:false;
				data "Jumlah Individu berstatus normal"
					value: {cycle/24, num_ICU} color: #white marker:false;
				}
		}
		
		display chart_3 refresh:(current_hour = 0) {
			chart "Data sembuh dan meninggal" type: xy background: #white axes:#white color: #black tick_line_color: #grey{
				data "Jumlah Individu dirawat di rumah sakit"
					value: {cycle/24, num_hospitalized} color: #green marker:false;
				data "Jumlah Individu dirawat di ICU"
					value: {cycle/24, num_ICU} color: #green marker:false;
				data "Jumlah Individu yang sembuh"
					value: {cycle/24, num_recovered} color: #blue marker:false;
				data "Jumlah Individu yang meninggal"
					value: {cycle/24, num_death} color: #red marker:false;
				}
		}
		
		display chart_3 refresh:(current_hour = 0) {
			chart "Data status ekonomi" type: xy background: #white axes:#white color: #black tick_line_color: #grey{
				data "Jumlah Individu yang masuk kategori miskin"
					value: {cycle/24, num_poor} color: #green marker:false;
				data "Jumlah keluarga yang masuk kategori miskin"
					value: {cycle/24, num_family_poor} color: #green marker:false;
				data "Jumlah Individu keluar dari kota"
					value: {cycle/24, num_travel} color: #blue marker:false;
				data "Jumlah Individu yang masuk ke kota"
					value: {cycle/24, num_come} color: #red marker:false;
				}
		}
	}
}

