/**
* Name: tugasAkhir
* Based on the internal empty template. 
* Author: Fadhil
* Tags: 
*/


model tugasAkhir

import "fungsi.gaml"

/* Insert your model definition here */

global{
	//General Parameter of Simulation
	int num_population <- 0; //Initial population
	int num_family; //Initial family, input from user
	int num_init_infected; //Initial confirmed status, input from user
	list<string> status_traveler <- [ //Status perjalanan agen manusia
		"none", "commuter", "leave", "come"
	];
	int simulation_days; //Jumlah hari simulasi, input uset
	
	float test_accuracy;
	float contact_tracing_effectiveness; //Input from user
	float sensitivity_pcr <- 0.943; //Data from journal
	float specificity_pcr <- 0.959; //Data from journal
	float sensitivity_rapid <- 0.775; //Search data from journal
	float specificity_rapid <- 0.87; //Search data from journal
	float quarantine_obedience <- 0.73; //Initial obedience from data in journal
	float mask_effectiveness <- 0.77;
	int lockdown_threshold; //Jumlah infeksi lockdown dilaksanakanan, input user
	bool lockdown <- false; //Status lockdown
	float activity_reduction_lockdown;
	float infection_reduction_lockdown <- rnd(0.45,0.7);
	int mobility_lockdown <- 5; //Input user, hari terjadi mobilisasi sesuai standar
	bool psbb <- false;
	int psbb_threshold; //Input user
	float activity_reduction_psbb;
	float infection_reduction_psbb <- rnd(0.35,0.55);
	int new_normal_threshold; //Jumlah infeksi turun jika lockdown dilepas, input user
	bool new_normal <- false; //Status lepas lockdown
	float activity_reduction_newnormal;
	float infection_reduction_newnormal <- rnd(0.25,0.35);
	int normal_threshold; //Input user
	float proba_travel <- 0.0005; //Kemungkinan orang melakukan perjalanan
	float proba_travel_infected <- 0.25;
	int poor_threshold;
	
	
	//Demographical Parameters
	int min_age <- 1;
	int min_student_age <- 4;
	int max_student_age <- 24;
	int min_working_age <- 15;
	int max_working_age <- 60;
	int max_age <- 100;
	float proba_15_school <- 0.6982; //sumber: BPS Surabaya & BPS Nasional
	float proba_19_school <- 0.1176; 
	
	float proba_active_family <- 0.9; //Di cek lagi kemungkinannya
	float proba_employed_male <- 0.8251; //Jumlah laki2 bekerja
	float proba_employed_female <- 0.5089; //Jumlah perempuan bekerja
	float proba_works_at_home <- 0.03; //Jumlah WFH
	int max_num_children <- 3; //Belum
	float proba_others <- 0.25;
	float proba_grandfather <- 0.175; //Belum
	float proba_grandmother <- 0.175; //Belum
	
	//TIME DIVISION
	list<int> morning <- [7,8,9,10];
	list<int> daytime <- [11,12,13,14];
	list<int> evening <- [15,16,17,18];
	list<int> night <- [19,20,21,22];
	list<int> midnight <- [23,0,1,2,3,4,5,6];
	list<list<int>> time_of_day <- [morning, daytime, evening, night];
	
	//EPIDEMIOLOGICAL PARAMETERS
	list<string> status_covid <- [ //Status agen manusia
		"suspect", "probable", "confirmed", "discarded", "kontak erat", "death", "recovered", "normal"
	];
	list<string> severity <- [ //Keparahan penyakit
		"asymptomic", "mild", "moderate", "severe"
	];
	list<string> symptomp <- [ //Keparahan penyakit
		"asymptomic", "mild", "moderate", "severe"
	];
	map<list<int>,list<float>> susceptibility <- [ //Kerentanan
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,9]::[0.395,0.082],
		[10,19]::[0.375,0.067],
		[20,29]::[0.79,0.104],
		[30,39]::[0.865,0.082],
		[40,49]::[0.8,0.089],
		[50,59]::[0.82,0.089],
		[60,69]::[0.88,0.074],
		[70,max_age]::[0.74,0.089]
	];
	map<list<int>,int> incubation_distribution <- [ 
	//Distribusi periode inkubasi berdasarkan umur, rata2 4-5 hari bisa dicari lagi
		[0,14]::3,
		[15,29]::5,
		[30,44]::4,
		[45,59]::3,
		[60,74]::2,
		[75,89]::2,
		[89,max_age]::2
	];
	map<list<int>,float> asymptomic_distribution <- [
	//Kemungkinan asimptomp berdasarkan umur
		 
		[0,19]::0.701,
		[20,29]::0.626,
		[30,39]::0.596,
		[40,49]::0.573,
		[50,59]::0.599,
		[60,69]::0.616,
		[70,max_age]::0.687
	];
	map<list<int>,float> moderate_distribution <- [
	//Kemungkinan dirawat, untuk menentukan mild or moderate
		 
		[0,9]::0.26,
		[10,19]::0.07,
		[20,29]::0.14,
		[30,49]::0.2,
		[50,69]::0.37,
		[70,max_age]::0.55
	];
	map<list<int>,float> hospitalization_distribution <- [
	//Kemungkinan dirawat, untuk menentukan mild or moderate
		 
		[0,9]::0.26,
		[10,19]::0.07,
		[20,29]::0.14,
		[30,49]::0.2,
		[50,69]::0.37,
		[70,max_age]::0.55
	];
	map<list<int>,float> ICU_distribution <- [
	//Kemungkinan masuk ICU, untuk menentukan moderate or severe
		[0,9]::0.008,
		[10,19]::0.01,
		[20,29]::0.006,
		[30,49]::0.011,
		[50,69]::0.037,
		[70,max_age]::0.032
	];
	map<list<int>,float> fatality_distribution <- [ //Nemu
	//Kemungkinan fatal, between severe and death
		[0,9]::0,
		[10,19]::0.004,
		[20,29]::0.003,
		[30,49]::0.002,
		[50,69]::0.014,
		[70,max_age]::0.11
	];
	map<list<int>,float> death_distribution <- [ //Nemu
	//Kemungkinan kematian jika keadaan Covid
		[0,9]::0.01,
		[10,19]::0.002,
		[20,29]::0.002,
		[30,49]::0.004,
		[50,59]::0.013,
		[60,69]::0.036,
		[70,79]::0.08,
		[80,max_age]::0.15
	];
	//list<float> days_diagnose <- [3.57,0.65]; //Hari menuju terdiagnosa
	map<list<int>, list<float>> days_diagnose <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,9]::[3.0,1.2],
		[10,19]::[5.0,1.81],
		[20,29]::[5.0,0.89],
		[30,39]::[4.0,0.64],
		[40,49]::[3.0,0.87],
		[50,59]::[2.0,0.84],
		[60,69]::[2.0,0.89],
		[70,max_age]::[2.0,0.97]
	];
	map<list<int>, list<float>> days_symptom_until_recovered <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		[1,9]::[17.65,1.2],
		[10,19]::[19.35,1.81],
		[20,29]::[19.25,0.89],
		[30,39]::[19.25,0.64],
		[40,49]::[21.7,0.87],
		[50,59]::[22.45,0.84],
		[60,69]::[22.95,0.89],
		[70,max_age]::[24.4,0.97]
	];
	
	
	//BEHAVIORAL PARAMETERS
	float proba_test <- 0.95; //Kemungkinan test
	float proba_activity_morning <-0.15;
	float proba_activity_daytime <-0.25;
	float proba_activity_evening <-0.325;
	float proba_activity_night <-0.05;
	list<float> proba_activities <- [
		proba_activity_morning,
		proba_activity_daytime,
		proba_activity_evening,
		proba_activity_night
	];
	float activity_reduction_factor <- 0.0;
	float mask_usage_proportion <- 0.75; //Ga sesuai sumber atau sumbernya dari paper di grup
	float infection_reduction_factor <- 0.1; //https://ejournal.upi.edu/index.php/image/article/download/24189/pdf
	float proportion_quarantined_transmission <- 0.1; //Ga sesuai sumber???
	float obedience; //(Penting) Dipisah sebaiknya satu persatu. Ini bukannya udah ada di parameter.gaml?
	
	//Economical Parameter
	map<string, list<float>> salary_by_places <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		"kindergarten"::[650.0,900.0],
		"elementary_school"::[650.0,1175.0],
		"junior_high_school"::[650.0,1175.0],
		"senior_high_school"::[650.0,1175.0],
		"university"::[650.0,1275.0],
		"marketplace"::[500.0,2500.0],
		"mall"::[500.0,2000.0],
		"store"::[250.0,25250.0],
		"supermarket"::[500.0,600.0],
		"village_office"::[500.0,762.5],
		"subdistrict_office"::[675,962.5],
		"government_office"::[850,1187.5],
		"post_office"::[500.0,750.0],
		"bank"::[687.5,1500.0],
		"community_group_office"::[500.0,762.5],
		"office"::[1000.0,12500.00],
		"commercial"::[1000.0,12500.00],
		"embassy"::[1150.0,2734.0],
		"cafe"::[500.00,2250.0],
		"clinic"::[500.5,916.5],
		"hospital"::[600.0,2625.0],
		"police"::[500.0,732.0],
		"industrial"::[1000.0,5000.00]
	];
	
	map<string, int> capacity_by_places <- [
		/*
		 * Tipe data berbentuk map, yang memetakan rentang usia
		 * dengan parameter distribusi probabilitas.
		 */
		 
		"kindergarten"::50,
		"elementary_school"::300,
		"junior_high_school"::200,
		"senior_high_school"::200,
		"university"::1000,
		"marketplace"::100,
		"mall"::1000,
		"store"::50,
		"supermarket"::50,
		"village_office"::30,
		"subdistrict_office"::30,
		"government_office"::30,
		"post_office"::50,
		"bank"::50,
		"community_group_office"::30,
		"office"::100,
		"commercial"::100,
		"embassy"::50,
		"cafe"::20,
		"clinic"::1000,
		"hospital"::1000,
		"police"::30,
		"public"::1000,
		"pumping_station"::50,
		"industrial"::1000,
		"mosque"::50,
		"church"::50,
		"temple"::50,
		"cemetery"::100000,
		"train_station"::100000
	];
	
	//STRING CONSTANTS
	//Ntar ditinjau ulang
	string suspect <- "suspect"; 
	string probable <- "probable";
	string confirmed <- "confirmed"; 
	string discarded <- "discarded"; 
	string kontak_erat <- "kontak erat"; 
	string death <- "death";
	string recovered <- "recovered"; 
	string normal <- "normal";
	string home <- "home";
	string asymptomic <- "asymptomic";
	string hospital <- "hospital";
	string ICU <- "ICU";
	string house <- "house";
	string mild <- "mild";
	string moderate <- "moderate";
	string severe <- "severe";
	string deadly <- "deadly";
	string none <- "none";
	string leave <- "leave";
	string commuter <- "commuter";
	string come <- "come";
	string infected <- "infected";
	string exposed <- "exposed";
	string rapid <- "rapid";
	string pcr <- "pcr";
}