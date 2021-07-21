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
	
	action user_inputs {
		map<string,unknown> values1 <- user_input("Masukkan jumlah hari yang akan disimulasikan.",[enter("Hari",60)]);
		simulation_days <- int(values1 at "Hari");
		map<string,unknown> values2 <- user_input("Masukkan jumlah keluarga di pemodelan.",[enter("Keluarga",5)]);
		num_family <- int(values2 at "Keluarga");
		map<string,unknown> values3 <- user_input("Masukkan jumlah individu terinfeksi di awal.",[enter("Jumlah",5)]);
		num_init_confirmed <- int(values3 at "Jumlah");
		map<string,unknown> values4 <- user_input("Masukkan berapa threshold jumlah pasien yang dirumahsakitkan sehingga terjadi PSBB.",[enter("Orang",3)]);
		lockdown_threshold <- int(values4 at "Orang");
		map<string,unknown> values5 <- user_input("Masukkan berapa hari terjadi penurunan konfirmasi positif sampai PSBB dilonggarkan",[enter("Hari",14)]);
		new_normal_threshold <- int(values5 at "Hari");
		map<string,unknown> values6 <- user_input("Masukkan persen efektivitas contact tracing.",[enter("(%)",100)]);
		contact_tracing_effectiveness <- int(values6 at "(%)")/100.0;	
	}
}
/* Insert your model definition here */

